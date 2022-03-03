<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Airgap OpenShift Installation on IBM Cloud VMware Solutions Shared based on VMware Cloud Director](#airgap-openshift-installation-on-ibm-cloud-vmware-solutions-shared-based-on-vmware-cloud-director)
  - [Overview](#overview)
      - [Setting up mirror registry](#setting-up-mirror-registry)
        - [Setting up of registry via automated script](#setting-up-of-registry-via-automated-script)
        - [Setting up of registry manually via redhat documented steps](#setting-up-of-registry-manually-via-redhat-documented-steps)
      - [Create a mirror for OpenShift 4.6 images](#create-a-mirror-for-openshift-46-images)
      - [Create a mirror for Redhat Openshift catalogs](#create-a-mirror-for-redhat-openshift-catalogs)
      - [Setup airgap pre-requisites](#setup-airgap-pre-requisites)
        - [Add the mirror creds in the pull-secret.json](#add-the-mirror-creds-in-the-pull-secretjson)
        - [Copy registry cert in case of registry setup in different VCD](#copy-registry-cert-in-case-of-registry-setup-in-different-vcd)
        - [Update the terraform.tfvars airgap parameters](#update-the-terraformtfvars-airgap-parameters)
      - [Post install cluster configuration](#post-install-cluster-configuration)
        - [Configure mirrored redhat operators catalog](#configure-mirrored-redhat-operators-catalog)
      - [Storage Configuration](#storage-configuration)
  - [How to increase existing bastion server disk capacity for mirroring of the images](#how-to-increase-existing-bastion-server-disk-capacity-for-mirroring-of-the-images)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Airgap OpenShift Installation on IBM Cloud VMware Solutions Shared based on VMware Cloud Director
## Overview
Deploy OpenShift on IBM Cloud VMware Solutions based on VMware Cloud Director.  This toolkit uses Terraform to automate the OpenShift installation process including the Edge Network configuration, Bastion host creation, OpenShift CoreOS bootstrap, loadbalancer, control and worker node creation. Once provisioned, the VMware Cloud Director environment gives you complete control of all aspects of you OpenShift environment.

This document helps you to configure "airgapped" clusters without Internet access.

Please follow the steps from main document [high level steps to setup the airgap cluster](../README.md#high-level-steps-for-setting-up-the-cluster-as-airgap-install) using this toolkit

**NOTE**: OpenShift 4.6 or later is supported. If you need 4.5 or earlier, see the [VCD Toolkit](https://github.com/vmware-ibm-jil/vcd_toolkit_for_openshift) or the `terraform-openshift4-vmware pre-4.6` [branch](https://github.com/ibm-cloud-architecture/terraform-openshift4-vmware/tree/pre-4.6)


#### Setting up mirror registry

**NOTE**: If you have a mirror registry already setup  with the OCP images mirrored , in some other VCD by your team, then you can skip setting up the mirror registry and directly create the OCP cluster by following the instructions [High Level Steps for setup cluster](../README.md#architecture)


##### Setting up of registry via automated script

You can run this script [setup_simple_private_registry.sh](scripts/setup_simple_private_registry.sh) to setup simple private registry on your bastion server

* You need to edit the below parameters in the script [setup_simple_private_registry.sh](scripts/setup_simple_private_registry.sh)

```sh
#Parameters for TLS Certificate usage.
 #This parameter is to be set in case you need to setup your registry with existing TLS CERT file.
export REGISTRY_SETUP_WITH_EXISTING_TLS_CERTIFICATE="false"
 #Certificate key filename, if you have existing file you can provide the name here, else in case if you dont have one then the script creates one with self signed certificate key file
 #use this name if you dont have file of yours ex: '$HOSTNAME-$REGISTRY_PORT_NUMBER.key'
 #NOTE: If you provide your existing filename then you need to make sure it is present in the directory path as per the parameter 'CERTS_DIR' below
export REGISTRY_HTTP_TLS_KEY_FILENAME="$HOSTNAME-$REGISTRY_PORT_NUMBER.key"
 #Certificate crt filename, if you have existing file you can provide the name here , else in case if you don't have one then the script creates one with self signed certificate crt file
 #use this name if you don't have file of yours ex : '$HOSTNAME-$REGISTRY_PORT_NUMBER.crt'
 #NOTE: If you provide your existing filename then you need to make sure it is present in the directory path as per the parameter 'CERTS_DIR' below
export REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME="$HOSTNAME-$REGISTRY_PORT_NUMBER.crt"

#Parameters for registry directory paths
 #Provide the registry directory ex : '/opt/test2_registry'.
export registry_dir="/opt/test2_registry"
 #Provide the Auth directory where registry access crendentials file will be created by the script. ex : '$registry_dir/auth'
export AUTH_DIR="$registry_dir/auth"
 #Provide the Certs directory which will be used to either generate self signed certificate, or where you have existing TLS certificate file. ex : '$registry_dir/certs'
export CERTS_DIR="$registry_dir/certs"
 #Provide the Data directory which will be used by the registry to store the data. ex: '$registry_dir/data'
export DATA_DIR="$registry_dir/data"


#Parameters for registry credentials to access it.
 #Username for your registry to access it once it is created.
export registry_username_to_be_created="test_user"
 #Password for your registry to access it once it is created.
export registry_password_to_be_set="simplepassword"

#Parameters for registry name and port number
 #Registry name that you want to setup
export REGISTRY_NAME="registry123"
 #Port number for the the registry to be accessed later once it is created.
export REGISTRY_PORT_NUMBER="5004"


```

* Now you can execute the script to install the Strimzi operator

```
 ./scripts/setup_simple_private_registry.sh
```

* In order to prevent an x509 untrusted CA error during the terraform apply step, you must currently copy your mirror certificate to this directory and trust it. I should be able to fix this in the future.  
```
cp <your mirror cert> /etc/pki/ca-trust/source/anchors/
update-ca-trust
trust list | grep -i "<hostname>"
```

##### Setting up of registry manually via redhat documented steps

You need a mirror registry to mirror the OCP release images so it can be used to create the OCP cluster further. A simple registry setup instructions can be found [here](https://www.redhat.com/sysadmin/simple-container-registry).

* In order to prevent an x509 untrusted CA error during the terraform apply step, you must currently copy your mirror certificate to this directory and trust it. I should be able to fix this in the future.  
```
cp <your mirror cert> /etc/pki/ca-trust/source/anchors/
update-ca-trust
trust list | grep -i "<hostname>"
```
The last command will check to see if the update was successful.

#### Create a mirror for OpenShift 4.6 images
You will need to create your own mirror or use an existing mirror to do an airgapped install. Instructions to create a mirror for OpenShift 4.6 can be found [here](https://docs.openshift.com/container-platform/4.6/installing/installing-mirroring-installation-images.html).

After following the instructions above, you should have a pull secret file on your server.  You will need to know this path as it will be used to update the tfvars file in the next section.

In order for the accept CSR code to work, you will have to:
```  
podman pull quay.io/openshift/origin-cli:latest
podman tag quay.io/openshift/origin-cli:latest <mirror_fqdn>:<mirror_port>/openshift/origin-cli:latest  
podman push <mirror_fqdn>:<mirror_port>/openshift/origin-cli:latest
````

#### Create a mirror for Redhat Openshift catalogs

You will also need to mirror any operators that you will need and place them in the mirror. Instructions can be found [here](https://docs.openshift.com/container-platform/4.6/operators/admin/olm-restricted-networks.html)

**NOTE** Only follow the instructions for mirroring the catalog images and save the `imageContentSourcePolicy.yaml` and `catalogSource.yaml` that gets generated  in the directory `manifests-<index_image_name>-<random_number>` after the `oc adm catalog mirror` command is completed. These two files needs to be shared with the team who would use this shared registry to get the redhat catalogs setup in their airgap cluster once it will be created by them.


#### Setup airgap pre-requisites

##### Add the mirror creds in the pull-secret.json 

Follow thes steps to add your shared registry credentials in the pull-secret.json [Adding shared mirror registry creds in redhat pull-secret.json](https://docs.openshift.com/container-platform/4.4/installing/install_config/installing-restricted-networks-preparations.html#installation-adding-registry-pull-secret_installing-restricted-networks-preparations)

**NOTE** **Disable Telemetry:** You should edit your pull secret and remove the section that refers to `cloud.openshift.com`. This removes Telemetry and Health Reporting. If you don't do this before installation of OCP cluster, you will get an error in the insights operator.

##### Copy registry cert in case of registry setup in different VCD

This is special step and you have to perform it only if you have your mirror registry setup in other VCD than your current VCD where you are trying to create the OCP cluster.

**Pre-requisite**

* Access to the shared registry `domain.crt` file.

**Steps**

* User have to manually copy  the registry cert file `domain.crt` (cert file for the registry ) from the shared location by your team, to your current hostmachine where you will be creating the cluster (standard location to keep this file: `/opt/registry/certs/domain.crt`). 

* Further mention it in the `terraform.tfvars` as below : 

```
additionalTrustBundle = "/opt/registry/certs/domain.crt"
```

* In order to prevent an x509 untrusted CA error during the terraform apply step, you must currently copy your mirror certificate to this directory and trust it. I should be able to fix this in the future.  
```
cp <your mirror cert> /etc/pki/ca-trust/source/anchors/
update-ca-trust
trust list | grep -i "<hostname>"
```

##### Update the terraform.tfvars airgap parameters



Next update your terraform.tfvars file to create the cluster and enable airgap install. We will have to make changes in below sections.

* Update the trust bundle for your mirror registry following steps [Copy registry cert in case of registry setup in different VCD](#copy-registry-cert-in-case-of-registry-setup-in-different-vcd)


* Update the redhat_pull_secret with the file path that was updated from [Add the mirror creds in the pull-secret.json](#add-the-mirror-creds-in-the-pull-secretjson):

```
openshift_pull_secret = "<path to pull secret JSON file created in the previous section>"
```

* Update the `airgapped` object based on the example below:
  *  Update `enabled = true`
  *  Provide the mirror registry details for the shared mirror registry where all your OCP images are mirrored , this will help to install the OCP cluster further.

```
airgapped = {
      enabled = true
      ocp_ver_rel = "4.6.15"
      mirror_ip = "172.16.0.10"
      mirror_fqdn = "bastion.airgapfull.cdastu.com"
      mirror_port = "5000"
      mirror_repository = "ocp4/openshift4"
      }
```

* Update the `initialization_info` object to set `run_cluster_install` to true as shown in the example below:
  * Updated `run_cluster_install = true` , which will create the OCP cluster
  * Update the `public_bastion_ip` and `cluster_public_ip` with the public ips that are available for your VCD

cluster_public_ip       = "161.xxx.x.xxx"

```
 initialization_info     = {
    public_bastion_ip = "161.xxx.xx.xxx"
    bastion_password = "OCP4All"
    internal_bastion_ip = "172.16.0.10"
    terraform_ocp_repo = "https://github.com/ibm-cloud-architecture/terraform-openshift4-vcd"
    rhel_key = "xxxxxxxxxxxxxxxxxxxxxx"
    machine_cidr = "172.16.0.1/24"
    network_name      = "ocpnet"
    static_start_address    = "172.16.0.150"
    static_end_address      = "172.16.0.220"
    run_cluster_install     = true
    }
```

#### Post install cluster configuration

**Disable Telemetry:** After installation, go [here](https://docs.openshift.com/container-platform/4.6/support/remote_health_monitoring/opting-out-of-remote-health-reporting.html) for instructions to disable Telemetry Reporting.

Run this command to stop OpenShift from looking for Operators from the Online source.  

`oc patch OperatorHub cluster --type json  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'`

You may receive an Alert stating `Cluster version operator has not retrieved updates in xh xxm 17s. Failure reason RemoteFailed . For more information refer to https://console-openshift-console.apps.<cluster_id>.<base_domain>.com/settings/cluster/` this is normal and can be ignored.

##### Configure mirrored redhat operators catalog

Assuming that you have a mirror registry and you have redhat catalog mirror created, now you will configure the catalog access by following below steps

**Pre-requisite**:
* Redhat catalogs are mirrored by following the earlier instructions [create a mirror for redhat openshift catalogs](#create-a-mirror-for-redhat-openshift-catalogs)
* You need to have the shared files `imageContentSourcePolicy.yaml` and `catalogSource.yaml` that was generated as a process of mirroring the catalogs in shared registry.

**Steps**:
* Once you have the access to these files run below commands:

Setting the mirror policy for the catalog images

```
oc apply -f imageContentSourcePolicy.yaml
```

Creating the catalogsource for the mirrored catalogs

```
oc apply -f catalogSource.yaml
```

#### Storage Configuration

If you need to configure a storageclass, there are a few options.  You can follow these instructions for setting up NFS or rookcephfs [here](airgap-storage.md).


# How to increase existing bastion server disk capacity for mirroring of the images

In case when you want to increase the capacity of the disk on the bastion server which has shared mirror registry, you can use these steps.
**Steps**:

* Expanding the disk capacity for the Bastion server from the  VCloud director console.

1. Goto to cloud.ibm.com and under your account and in the hamburger menu select your your `VMwhare->resources`.
2. In the `VMware Solutions Shared ` click your resource name and inside that click the `vCloud director console` for your resource and sign in.
3. In the Virtual Data Center select your VDC under which you have your Bastion server setup with the mirror registry.
4. Click on vApps and select the bastion server.
5. Click `Hardware-> Hard Disks`
6. Click edit and increase the size of the disk from 1000 GB to 3000 GB(Depending on your capacity requirement).

<img width="1440" alt="Screen Shot 2021-08-18 at 5 15 47 PM" src="https://media.github.ibm.com/user/186069/files/f5504800-0047-11ec-816f-e265bcd868c4">

* Now steps to configure linux on the bastion server to enable the extended disk capacity usage.

1. SSH to the bastion server for your VDC(Virtual Data Center)
2. Run below command to find out the pvc names

```
# lsblk
```

3. Run below commands to enable the hard disk whose capacity is extended to register it with the linux os on that bastion server.

Commands:
```console
(echo n;echo p;echo 3;echo ;echo ;echo t;echo 3;echo 8e;echo w) | fdisk /dev/sda > /dev/null 2>&1; fdisk -l /dev/sda
partprobe
pvcreate /dev/sda4
vgextend rhel /dev/sda4
vgdisplay -v
lvextend -l +100%FREE /dev/rhel/root
xfs_growfs  /dev/rhel/root
```
NOTE: Here `sda4` depends on your volume mount name as per above command

4. Finally after execution of above commands run the commands to verify if your disk capacity is extended and configured.

```console
]# lsblk
NAME          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda             8:0    0    3T  0 disk 
├─sda1          8:1    0    1G  0 part /boot
├─sda2          8:2    0   31G  0 part 
│ ├─rhel-root 253:0    0    2T  0 lvm  /
│ └─rhel-swap 253:1    0  3.2G  0 lvm  [SWAP]
├─sda3          8:3    0  968G  0 part 
│ └─rhel-root 253:0    0    2T  0 lvm  /
└─sda4          8:4    0    1T  0 part 
  └─rhel-root 253:0    0    2T  0 lvm  /
sr0            11:0    1 1024M  0 rom  

[root@bastion-cp4waiops-registry-cp4waiops-shared-registry-cluster ~]# df -H
Filesystem             Size  Used Avail Use% Mounted on
devtmpfs               4.1G     0  4.1G   0% /dev
tmpfs                  4.1G   87k  4.1G   1% /dev/shm
tmpfs                  4.1G  9.4M  4.1G   1% /run
tmpfs                  4.1G     0  4.1G   0% /sys/fs/cgroup
/dev/mapper/rhel-root  2.2T  828G  1.4T  38% /
/dev/sda1              1.1G  269M  795M  26% /boot
tmpfs                  815M     0  815M   0% /run/user/0
```

NOTE: If you observer the `sda4` is added with the size.
