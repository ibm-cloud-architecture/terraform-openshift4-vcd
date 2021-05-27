# Airgap OpenShift Installation on IBM Cloud VMWare Solutions Shared based on VMWare Cloud Director
## Overview
Deploy OpenShift on IBM Cloud VMWare Solutions based on VMWare Cloud Director.  This toolkit uses Terraform to automate the OpenShift installation process including the Edge Network configuration, Bastion host creation, OpenShift CoreOS bootstrap, loadbalancer, control and worker node creation. Once provisioned, the VMWare Cloud Director environment gives you complete control of all aspects of you OpenShift environment.

The toolkit provides the flexibility to also configure "airgapped" clusters without Internet access.

See also [IBM Cloud VMWare Solutions Shared overview](https://cloud.ibm.com/docs/vmwaresolutions?topic=vmwaresolutions-shared_overview)

This toolkit performs an OpenShift UPI type install and will provision CoreOS nodes using static IP addresses. The `ignition` module will inject code into the cluster that will automatically approve all node CSRs.  This runs only once at cluster creation.  You can delete the `ibm-post-deployment` namespace once your cluster is up and running.

**NOTE**: OpenShift 4.6 or later is supported. If you need 4.5 or earlier, see the [VCD Toolkit](https://github.com/vmware-ibm-jil/vcd_toolkit_for_openshift) or the `terraform-openshift4-vmware pre-4.6` [branch](https://github.com/ibm-cloud-architecture/terraform-openshift4-vmware/tree/pre-4.6)

## Architecture

OpenShift 4.6 User-Provided Infrastructure

![topology](./media/vcd_arch.png)

# Installation Process
## Order a VCD
You will order a **VMware Solutions Shared** instance in IBM Cloud(below).  When you order a new instance, a **DataCenter** is created in vCloud Director.  It takes about an hour.

#### Procedure:
* in IBM Cloud > VMWare > Overview,  select **VMWare Solutions Shared**
* name your virtual data center
* pick the resource group.  
* agree to the terms and click `Create`
* then in VMware Solutions > Resources you should see your VMWare Solutions Shared being created.  After an hour or less it will be **ready to use**You will need to edit terraform.tfvars as appropriate, setting up all the information necessary to create your cluster. You will need to set the vcd information as well as public ip's, etc. This file will eventually be copied to the newly created Bastion.


#### Initial VCD setup
* Click on the VMWare Shared Solution instance named from the Resources list
* Set your admin password, and save it
* Click the button to launch your  **vCloud Director console**
* We recommend that you create individual Users/passwords for each person accessing the environment
* Make note of the 5 public ip address on the screen. You will need to use them later to access the Bastion and your OCP clusters
* Note: You don't need any Private network Endpoints unless you want to access the VDC from other IBM Cloud accounts over Private network

# Installing the Bastion and initial network configuration
## Setup Host Machine
You will need a "Host" machine to perform the initial Bastion install and configuration. This process has only been tested on a RHEL8 Linux machine and a Mac but may work on other linux based systems that support the required software. You should have the following installed on your Host:
 - ansible [instructions here](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
 - git
 - terraform v0.13+ [instructons here](https://www.terraform.io/downloads.html)

On your Host, clone the git repository. After cloning the repo, You will need to edit `terraform.tfvars` as appropriate, setting up all the information necessary to create your cluster. You will need to set the vcd information as well as public ip's, etc. Instructions on gathering key pieces of informaton are below.

```
git clone https://github.com/ibm-cloud-architecture/terraform-openshift4-vcd
cd terraform_openshift4-vcd
cp terraform.tfvars.airgap.example terraform.tfvars
```
Edit terraform.tfvars per the terraform variables section
## Gather Information for terraform.tfvars
#### Find vApp Template from the Image Catalog
We need a catalog of VM images to use for our OpenShift VMs and the Bastion.
Fortunately IBM provides a set of images that are tailored to work for OpenShift deployments.
To browse the available images:
* From your vCloud Director console, click on **Libraries** in the header menu.
* select *vApp Templates*
* There may be several images in the list that we can use, pick the one that matches the version of OCP that you intend to install:
  * rhcos OpenShift 4.6.8 - OpenShift CoreOS template
  * rhcos OpenShift 4.7.0 - OpenShift CoreOS template
  * RedHat-8-Template-Official
* If you want to add your own Catalogs and more, see the [documentation about catalogs](#about-catalogs)

#### Networking Info
VCD Networking is covered in general in the [Operator Guide/Networking](https://cloud.ibm.com/docs/vmwaresolutions?topic=vmwaresolutions-shared_vcd-ops-guide#shared_vcd-ops-guide-networking). Below is the specific network configuration required.

Go your VCD console Edge Gateway/External Networks/Networks & Subnets and gather Network the network names. You will need to set the following variables in your `terraform.tfvars` file:
```
user_service_network_name = "<the network name with the word 'Service' in it>"
user_tenant_external_network_name  ="<the network name with the words 'tenant external' in it>"
```
![Edge Gateway Networks & Subnets](media/edge_gateway_networks.jpg)


The Bastion installation process will now create all the Networking entries necessary for the environment. You simply need to pick
 - a **Network Name** (ex. ocpnet)
 - a **Gateway/CIDR** (ex. 172.16.0.1/24)
 - an **external** ip for use by the Bastion
 - an **internal** ip for use by the bastion


The Default FW rules created will Deny all traffic except for the Bastion which will have access both to the Public Internet and the IBM Cloud Private Network. DNAT and SNAT rules will be set up for the Bastion to support the above.

When you create a cluster, the FW will be set up as follows.
- The loadbalancer will always have Internet access as it needs to pull images from docker.io and quay.io in order to operate properly.
- A DNAT rule will be set up so that you can access you cluster from your workstation regardless of whether or not you requested airgap.

DHCP is not enabled on the Network as it will interfere with the DHCP server running in the cluster. If you have previously enabled it for use in the vcd toolkit, you should now disable it.

You will need to assign static ip addresses, within the Gateway/CIDR range that you defined, for the loadbalance, control plane and workers. You will see sections in `terraform.tfvars`. **The ip addresses can't be defined above x.y.z.99 within your CIDR Range**. These definitions look like this:

```
// The number of compute VMs to create. Default is 3.
compute_count = 3
compute_disk =250000

// The IP addresses to assign to the compute VMs. The length of this list must
// match the value of compute_count.
     compute_ip_addresses = ["172.16.0.74","172.16.0.75"]


// Storage Nodes disk size must be at least 2097152 (2TB) if you want to install OCS

storage_count = 0
storage_disk = 2097152
//storage_ip_addresses = ["172.16.0.76", "172.16.0.77", "172.16.0.78"]
//storage_ip_addresses = ["172.16.0.35"]

```

#### Choosing an External IP  for your cluster and Bastion and retrieving the Red Hat Activation key
Configure the Edge Service Gateway (ESG) to provide inbound and outbound connectivity.  For a network overview diagram, followed by general Edge setup instruction, see: https://cloud.ibm.com/docs/vmwaresolutions?topic=vmwaresolutions-shared_vcd-ops-guide#shared_vcd-ops-guide-create-network

Each vCloud Datacenter comes with 5 IBM Cloud public IP addresses which we can use for SNAT and DNAT translations in and out of the datacenter instance.  VMWare vCloud calls these `sub-allocated` addresses.
The sub-allocated address are available in IBM Cloud on the vCloud instance Resources page.
Gather the following information that you will need when configuring the ESG:
* Make a `list of the IPs and Sub-allocated IP Addresses` for the ESG.   
![Public IP](media/public_ip.jpg)


- Take an unused IP and set `cluster_public_ip` and for `public_bastion_ip`
- The Red Hat Activation key can be retrieved from this screen to populate `rhel_key`
- Set `run_cluster_install` to false.  We need to configure the mirror registry first before we setup the cluster.

- Your terraform.tfvars entries should look something like this:    
```
 cluster_public_ip  = "161.yyy.yy.yyy"

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
    run_cluster_install     = false
    }
```

#### Retrieve pull secret from Red Hat sites
Retrieve the [OpenShift Pull Secret](https://cloud.redhat.com/openshift/install/vsphere/user-provisioned) and place in a file on the Bastion Server. Default location is `~/.pull-secret`

## Perform Bastion install
Once you have finished editing your terraform.tfvars file you can execute the following commands. Terraform will now create the Bastion, install and configure all necessary software and perform all network customizations associated with the Bastion. The terraform.tfvars file will be copied to the Bastion server. The pull secret and additionalTrustBundle will be copied to the Bastion if they were specified in terraform.tfvars and are in the specified location on the Host machine. If you plan to create the pull secret and additionalTrustBundle on the Bastion directly and didn't put them on your Host, ignore the error messages about the copy failing.
The results of the install can be found either on the Bastion in `/root/cluster_install.log` or on your Host machine in `~/cluster_install.log`.

```
terraform -chdir=bastion-vm init --var-file="../terraform.tfvars"
terraform -chdir=bastion-vm plan --var-file="../terraform.tfvars"
terraform -chdir=bastion-vm apply --var-file="../terraform.tfvars" --auto-approve
```

The result looks something like this:
```
null_resource.setup_bastion (local-exec): PLAY RECAP *********************************************************************
null_resource.setup_bastion (local-exec): 150.239.22.38              : ok=26   changed=26   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

null_resource.setup_bastion: Creation complete after 3m32s [id=1639642181061551613]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

login_bastion = "Next Step login to Bastion via: ssh root@1xxx.xx.xx.38"
```

#### Login to Bastion
Use the generated command to login to the Bastion
`ssh root@1xxx.xx.xx.38`
The result should look somthing like this below. You can ignore the messages about registering the Red Hat VM with the activation key as this was done as part of the provisioning

```
To register the Red Hat VM with your RHEL activation key in IBM RHEL Capsule Server, you must enable VM access to connect to the IBM service network.  For more information, see Enabling VM access to IBM Cloud Services by using the private network (https://cloud.ibm.com/docs/services/vmwaresolutions?topic=vmware-solutions-shared_vcd-ops-guide#shared_vcd-ops-guide-enable-access).

Complete the following steps to register the Red Hat VM with your RHEL activation key. For more information about accessing instance details, see Viewing Virtual Data Center instances (https://cloud.ibm.com/docs/services/vmwaresolutions?topic=vmware-solutions-shared_managing#shared_managing-viewing).

1) From the IBM Cloud for VMware Solutions console, click the instance name in the VMware Solutions Shared instance table.

2) On the instance details page, locate and make note of the Red Hat activation key.

3) Run the following commands from the Red Hat VM:

rpm -ivh http://52.117.132.7/pub/katello-ca-consumer-latest.noarch.rpm

uuid=`uuidgen`

echo '{"dmi.system.uuid": "'$uuid'"}' > /etc/rhsm/facts/uuid_override.facts

subscription-manager register --org="customer" --activationkey="${activation_key}" --force
Where:
${activation_key} is the Red Hat activation key that is located on the instance details page.

Last login: Sat Mar  6 01:50:40 2021 from 24.34.132.100
[root@vm-rhel8 ~]#

```
You can look to make sure that your pull secret was copied:
```
[root@vm-rhel8 ~]# ls
airgap.crt  pull-secret
[root@vm-rhel8 ~]#

```
You can now go to the vcd directory. It is now placed in /opt/terraform. You will find your terraform.tfvars in the directory. You can inspect it to ensure that it is complete.
```
[root@vm-rhel8 ~]# cd /opt/terraform/
[root@vm-rhel8 terraform]# ls
bastion-vm      haproxy.conf  lb       media    output.tf  storage  terraform.tfvars          variables.tf  vm
csr-approve.sh  ignition      main.tf  network  README.md  temp     terraform.tfvars.example  versions.tf
[root@vm-rhel8 terraform]#
```

#### Setting up mirror registry
You will need a registry to store your images. A simple registry can be found [here](https://www.redhat.com/sysadmin/simple-container-registry).

In order to prevent an x509 untrusted CA error during the terraform apply step, you must currently copy your mirror certificate to this directory and trust it. I should be able to fix this in the future.  
```
cp <your mirror cert>/etc/pki/ca-trust/source/anchors/
update-ca-trust
trust list | grep -i "<hostname>"
```
The last command will check to see if the update was successful.

#### Create a mirror for OpenShift 4.6 images
You will need to create your own mirror or use an existing mirror to do an airgapped install. Instructions to create a mirror for OpenShift 4.6 can be found [here](https://docs.openshift.com/container-platform/4.6/installing/install_config/installing-restricted-networks-preparations.html#installing-restricted-networks-preparations).

After following the instructions above, you should have a pull secret file on your server.  You will need to know this path as it will be used to update the tfvars file in the next section.

In order for the accept CSR code to work, you will have to:
```  
podman pull quay.io/openshift/origin-cli:latest
podman tag quay.io/openshift/origin-cli:latest <mirror_fqdn>:<mirror_port>/openshift/origin-cli:latest  
podman push <mirror_fqdn>:<mirror_port>/openshift/origin-cli:latest
````

#### Create the airgap cluster from bastion server

Next update your terraform.tfvars file to create the cluster and enable airgap install. The `terraform.tfvars` file that needs to be updated for this step is located in the `/opt/terraform` directory of the bastion server. We will have to make changes in three sections.

Update the redhat_pull_secret:

```
openshift_pull_secret = "<path to pull secret JSON file created in the previous section>"
```

Update the airgapped object based on the example below:

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

Update the initialization_info object to set `run_cluster_install` to true as shown in the example below:    
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



If your terraform.tfvars file is complete, you can run the commands to create your cluster. The FW, DNAT and /etc/hosts entries on the Bastion will now be created too. The following terraform commands needs to be executed from `/opt/terraform` dir on your bastion server.

```
terraform init
terraform apply --auto-approve
```

#### Client setup

On the **Client** that you will access the OCP Console, (your Mac, PC, etc.) add name resolution to direct console to the **Public IP** of the LoadBalancer in /etc/hosts on the client that will login to the Console UI.
  As an example:
```
  1.2.3.4 api.ocp44-myprefix.my.com
  1.2.3.4 api-int.ocp44-myprefix.my.com
  1.2.3.4 console-openshift-console.apps.ocp44-myprefix.my.com
  1.2.3.4 oauth-openshift.apps.ocp44-myprefix.my.com
```

**NOTE:** On a MAC, make sure that the permissions on your /etc/host file is correct.  
If it looks like this:   
`$ ls -l /etc/hosts
-rw-------  1 root  wheel  622  1 Feb 08:57 /etc/hosts`   

Change to this:  
`$ sudo chmod ugo+r /etc/hosts
$ ls -l /etc/hosts
-rw-r--r--  1 root  wheel  622  1 Feb 08:57 /etc/hosts`

#### Let OpenShift finish the installation:
Once terraform has completed sucessfully, you will see several pieces of information display. This data will also be written to `/root/<cluster_id>info.txt` on the Bastion and to` ~/<cluster_id>info.txt` on the Host computer. As sample is below:
```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

output_file = <<EOT
Kubeadmin         : User: kubeadmin password: rfbyV-ggmCs-oSKfT-Bfkjt
Public IP         : 161.156.27.227
OpenShift Console : https://console-openshift-console.apps.testfra.cdastu.com
Export KUBECONFIG : export KUBECONFIG=/opt/terraform/installer/testfra/auth/kubeconfig

Host File Entries:

161.156.27.227  console-openshift-console.apps.testfra.cdastu.com
161.156.27.227  oauth-openshift.apps.apps.testfra.cdastu.com


EOT


```
Once you power on the machines it should take about 20 mins for your cluster to become active. To debug see **Debugging the OCP installation** below.

- power on all the VMs in the VAPP.

- The cluster userid and password are output from the `terraform apply` command.
- You can copy the export command generated to define KUBECONFIG. Alternately, you can get the info using the following methods:

  - You can also retrieve the password as follows:  
  cd to authentication directory:  
   `cd <clusternameDir>/auth`
    This directory contains both the cluster config and the kubeadmin password for UI login
 - export KUBECONFIG= clusternameDir/auth/kubeconfig   

    Example:   
   `export KUBECONFIG=/root/terraform-openshift-vmware/installer/stuocpvmshared1/auth/kubeconfig`
- If you want to watch the install, you can  
  `ssh -i installer/stuocpvmshared1/openshift_rsa core@<bootstrap ip>`  into the bootstrap console and watch the logs. Bootstrap will print the jounalctl command when you login: `journalctl -b -f -u release-image.service -u bootkube.service`. You will see lots of messages (including error messages) and in 15-20 minutes, you should see a message about the bootstrap service completing. Once this happens, exit the bootstrap node.

  You can now watch the OpenShift install progress.

`oc get nodes`
```
 NAME                                  STATUS   ROLES    AGE   VERSION
 master-00.ocp44-myprefix.my.com   Ready    master   16m   v1.17.1+6af3663
 master-01.ocp44-myprefix.my.com   Ready    master   16m   v1.17.1+6af3663
 master-02.ocp44-myprefix.my.com   Ready    master   16m   v1.17.1+6af36
```

Watch the cluster operators. Confirm the RH cluster operators are all 'Available'

`watch -n 5 oc get co`

```
NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.5.22    True        False         False      79m
cloud-credential                           4.5.22    True        False         False      100m
cluster-autoscaler                         4.5.22    True        False         False      89m
config-operator                            4.5.22    True        False         False      90m
console                                    4.5.22    True        False         False      14m
csi-snapshot-controller                    4.5.22    True        False         False      18m
dns                                        4.5.22    True        False         False      96m
etcd                                       4.5.22    True        False         False      95m
image-registry                             4.5.22    True        False         False      91m
ingress                                    4.5.22    True        False         False      84m
insights                                   4.5.22    True        False         False      90m
kube-apiserver                             4.5.22    True        False         False      95m
kube-controller-manager                    4.5.22    True        False         False      95m
kube-scheduler                             4.5.22    True        False         False      92m
kube-storage-version-migrator              4.5.22    True        False         False      12m
machine-api                                4.5.22    True        False         False      90m
machine-approver                           4.5.22    True        False         False      94m
machine-config                             4.5.22    True        False         False      70m
marketplace                                4.5.22    True        False         False      13m
monitoring                                 4.5.22    True        False         False      16m
network                                    4.5.22    True        False         False      97m
node-tuning                                4.5.22    True        False         False      53m
openshift-apiserver                        4.5.22    True        False         False      12m
openshift-controller-manager               4.5.22    True        False         False      90m
openshift-samples                          4.5.22    True        False         False      53m
operator-lifecycle-manager                 4.5.22    True        False         False      96m
operator-lifecycle-manager-catalog         4.5.22    True        False         False      97m
operator-lifecycle-manager-packageserver   4.5.22    True        False         False      14m
service-ca                                 4.5.22    True        False         False      97m
storage                                    4.5.22    True        False         False      53m

```

#### Post install cluster configuration

**Disable Telemetry:** You should edit your pull secret and remove the section that refers to `cloud.openshift.com`. This removes Telemetry and Health Reporting. If you don't do this before installation, you will get an error in the insights operator. After installation, go [here](https://docs.openshift.com/container-platform/4.6/support/remote_health_monitoring/opting-out-of-remote-health-reporting.html) for instructions to disable Telemetry Reporting.

Run this command to stop OpenShift from looking for Operators from the Online source.  

`oc patch OperatorHub cluster --type json  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'`

You may receive an Alert stating `Cluster version operator has not retrieved updates in xh xxm 17s. Failure reason RemoteFailed . For more information refer to https://console-openshift-console.apps.<cluster_id>.<base_domain>.com/settings/cluster/` this is normal and can be ignored.

#### Mirror redhat operators catalog

You will also need to mirror any operators that you will need and place them in the mirror. Instructions can be found [here](https://docs.openshift.com/container-platform/4.6/operators/admin/olm-restricted-networks.html)

You will need to follow the instructions carefully in order to setup imagesources for any operators that you want to install.

#### tfvars configuration

If you would like understand how to further configure your tfvars file, refer to the [this table](https://github.com/ibm-cloud-architecture/terraform-openshift4-vcd/tree/patch-1#terraform-variables) for details on what all the properties mean.

#### Storage Configuration

If you need to configure a storageclass, there are a few options.  You can follow these instructions for setting up NFS or rookcephfs [here](airgap-storage.md).

#### Debugging the OCP installation

Refer to the steps in the main README in the https://github.com/ibm-cloud-architecture/terraform-openshift4-vcd#debugging-the-ocp-installation section.

## Optional Steps:

Refer to the steps in the main README in the https://github.com/ibm-cloud-architecture/terraform-openshift4-vcd#optional-steps section.

### Deleting Cluster (and reinstalling)

Refer to the steps in the main README in the https://github.com/ibm-cloud-architecture/terraform-openshift4-vcd#deleting-cluster-and-reinstalling section.
