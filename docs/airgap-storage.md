<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Setup persistent storage for Airgap cluster](#setup-persistent-storage-for-airgap-cluster)
  - [Create rook-cephfs Storage for persistent storage.](#create-rook-cephfs-storage-for-persistent-storage)
    - [Pre-requisite](#pre-requisite)
    - [Steps to setup rook-cephfs through automated script:](#steps-to-setup-rook-cephfs-through-automated-script)
    - [Steps to setup rook-cephfs manually](#steps-to-setup-rook-cephfs-manually)
    - [Steps to delete rook-cephfs Storage from the cluster.](#steps-to-delete-rook-cephfs-storage-from-the-cluster)
  - [Add an NFS Server to provide Persistent storage.](#add-an-nfs-server-to-provide-persistent-storage)
    - [Steps to setup](#steps-to-setup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Setup persistent storage for Airgap cluster
## Create rook-cephfs Storage for persistent storage.
### Pre-requisite

 - You need to have either some `storage-nodes` along with master and compute nodes , or have a separate hard disk storage present for all the master nodes and compute nodes for the `rook-cephfs` to work.
 
 example of `storage-nodes`
 ```
storage-00.aadeshpa-green-cluster.cp4waiops602.com         Ready    worker   4d    v1.19.0+a5a0987
storage-01.aadeshpa-green-cluster.cp4waiops602.com         Ready    worker   4d    v1.19.0+a5a0987
storage-02.aadeshpa-green-cluster.cp4waiops602.com         Ready    worker   4d    v1.19.0+a5a0987
 ```
 
 example of `extra hard disk to master and compute node`
 
 <img width="1410" alt="Screen Shot 2021-05-24 at 11 11 48 AM" src="https://media.github.ibm.com/user/186069/files/65397700-bc81-11eb-83e8-4022f48ae8f8">
 
 
 - The separate hard disk storage capacity depends on your requirements, for Cp4waiops we setup 200GB hard disk storage for each master and comput node of the cluster.

### Steps to setup rook-cephfs through automated script:

Since we are installing rook-cephfs in airgap cluster, we need to have a mirror registry setup beforehand and you need to provide its credentials to the script

* You need to edit the below parameters in the script [install_rook-cephfs_airgap.sh](scripts/install_rook-cephfs_airgap.sh)

```sh

# This is your mirror registry where you want to mirror the strimzi images
mirror_registry="<your-mirror-registry>:<port>"

#Provide the creds for your mirror registry
mirror_registry_username="<mirrror-registry-username>"
mirror_registry_password="<mirror-registry-password>"
```

* Now you can execute the script to install the Strimzi operator

```
 ./scripts/install_rook-cephfs_airgap.sh
```

* Verify the pods are running correctly

```console
oc get pods -n rook-ceph

NAME                                                              READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-69m6d                                            3/3     Running     0          8m13s
csi-cephfsplugin-6fhkf                                            3/3     Running     0          8m13s
csi-cephfsplugin-c5ft8                                            3/3     Running     0          8m13s
csi-cephfsplugin-fctwt                                            3/3     Running     0          8m13s
csi-cephfsplugin-j7jk2                                            3/3     Running     0          8m13s
csi-cephfsplugin-provisioner-678685c55-79v9k                      6/6     Running     0          8m12s
csi-cephfsplugin-provisioner-678685c55-vcxp9                      6/6     Running     0          8m12s
csi-cephfsplugin-q4hh7                                            3/3     Running     0          8m13s
csi-cephfsplugin-qgvz4                                            3/3     Running     0          8m13s
csi-cephfsplugin-wmkbs                                            3/3     Running     0          8m13s
csi-rbdplugin-2r89v                                               3/3     Running     0          8m14s
csi-rbdplugin-fsrm5                                               3/3     Running     0          8m14s
csi-rbdplugin-g5fgf                                               3/3     Running     0          8m14s
csi-rbdplugin-hzcz6                                               3/3     Running     0          8m14s
csi-rbdplugin-n9hlt                                               3/3     Running     0          8m14s
csi-rbdplugin-p2rh6                                               3/3     Running     0          8m14s
csi-rbdplugin-provisioner-6b86f8b7d6-5pnfc                        6/6     Running     0          8m14s
csi-rbdplugin-provisioner-6b86f8b7d6-whnqm                        6/6     Running     0          8m14s
csi-rbdplugin-qf95x                                               3/3     Running     0          8m14s
csi-rbdplugin-wb56l                                               3/3     Running     0          8m14s
rook-ceph-crashcollector-0335f10fed6b4e0529f7d7c1e8373091-m4zjx   1/1     Running     0          7m55s
rook-ceph-crashcollector-25f7f9755cf10757ce94b46df5fa3d70-4dhsg   1/1     Running     0          6m58s
rook-ceph-crashcollector-2dedc790ad9f798c4a5f0958bd5a2adf-hdbqs   1/1     Running     0          7m29s
rook-ceph-mds-myfs-a-5d76b6c67c-klcnv                             1/1     Running     0          6m59s
rook-ceph-mds-myfs-b-777cb64b8f-d2wkq                             1/1     Running     0          6m58s
rook-ceph-mgr-a-b8fc65fbd-cft8v                                   1/1     Running     0          7m29s
rook-ceph-mon-a-6c948dd6d-lv6zw                                   1/1     Running     0          8m7s
rook-ceph-mon-b-55fd45f884-md46s                                  1/1     Running     0          7m55s
rook-ceph-mon-c-f6dfb9975-pbjgw                                   1/1     Running     0          7m41s
rook-ceph-operator-78cf5f6f59-x84xs                               1/1     Running     0          8m29s
rook-ceph-osd-prepare-0335f10fed6b4e0529f7d7c1e8373091-89csw      0/1     Completed   0          7m25s
rook-ceph-osd-prepare-111964f401dbbf717da42d83975016f9-md9db      0/1     Completed   0          7m26s
rook-ceph-osd-prepare-25f7f9755cf10757ce94b46df5fa3d70-gcpcg      0/1     Completed   0          7m25s
rook-ceph-osd-prepare-2dedc790ad9f798c4a5f0958bd5a2adf-q522t      0/1     Completed   0          7m26s
rook-ceph-osd-prepare-de2339ea0101ca914ea77756cf95b292-zx4z7      0/1     Completed   0          7m28s
rook-ceph-osd-prepare-e460b4ae84ca1e50e7ce2533c838495a-d4fwj      0/1     Completed   0          7m27s
rook-ceph-osd-prepare-f93fa49ad4c8f6ee82358a6329fd5d84-flc5j      0/1     Completed   0          7m26s
rook-ceph-osd-prepare-fd503266f7403c9e04873772d6dfdd28-grhs5      0/1     Completed   0          7m27s
```

### Steps to setup rook-cephfs manually

You can setup `rook-cephfs` storage in your airgap cluster by following below steps:

1. Clone the repository for rook, we have tested with the `--branch v1.5.8` which works correctly in OCP cluster 4.6 and that is airgapped.

```
git clone https://github.com/rook/rook --branch v1.5.8
```

2. Mirror the below images manually into your internal registry if you are using above version, else you would need to find the correct images as per given files from the cloned repository.

Example:

```shell
podman pull <original_image>
podman tag <original_image> <registry_hostname>:<registry_port>/<namspace>/<image:tag>
podman push <registry_hostname>:<registry_port>/<namspace>/<image:tag>

registry_hostname : your internal container registry hostname
registry_port : your internal container registry port
namespace : namespace as per the orignal image
image:tag : image name and its tag name


podman pull docker.io/rook/ceph:v1.5.8
podman tag docker.io/rook/ceph:v1.5.8 <registry_hostname>:<registry_port>/rook/ceph:v1.5.8
podman push <registry_hostname>:<registry_port>/rook/ceph:v1.5.8
```
Repeat the above example commands `podman pull, tag and push` to mirror all the below images from the given files

File : `rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml `

Images:

```yaml
spec:
  serviceAccountName: rook-ceph-system
  containers:
  - name: rook-ceph-operator
    image: docker.io/rook/ceph:v1.5.8
.
.
.
.
ROOK_CSI_CEPH_IMAGE: "quay.io/cephcsi/cephcsi:v3.2.0"
ROOK_CSI_REGISTRAR_IMAGE: "k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.0.1"
ROOK_CSI_RESIZER_IMAGE: "k8s.gcr.io/sig-storage/csi-resizer:v1.0.0"
ROOK_CSI_PROVISIONER_IMAGE: "k8s.gcr.io/sig-storage/csi-provisioner:v2.0.0"
ROOK_CSI_SNAPSHOTTER_IMAGE: "k8s.gcr.io/sig-storage/csi-snapshotter:v3.0.0"
ROOK_CSI_ATTACHER_IMAGE: "k8s.gcr.io/sig-storage/csi-attacher:v3.0.0"

```

File : `rook/cluster/examples/kubernetes/ceph/cluster.yaml`
  
Images: 

```yaml
spec:
  cephVersion:
    image: docker.io/ceph/ceph:v15.2.9

```



3. Update the image urls for all the images in above mentioned files, by updating the original registry of the image with your internal container registry where you mirrored above images.

Example: For File `rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml`

```yaml
spec:
  serviceAccountName: rook-ceph-system
  containers:
  - name: rook-ceph-operator
    image: <registry_hostname>:<registry_port>/rook/ceph:v1.5.8
        
```
NOTE: Make sure all the above mentioned images in above point has been updated in the given yaml files, before moving ahead.


4. Finally apply all the yaml files as shown below to setup the `rook-cephfs` storage

```shell
oc create -f ./rook/cluster/examples/kubernetes/ceph/crds.yaml
oc create -f ./rook/cluster/examples/kubernetes/ceph/common.yaml
oc create -f ./rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
oc create -f ./rook/cluster/examples/kubernetes/ceph/cluster.yaml
oc create -f ./rook/cluster/examples/kubernetes/ceph/filesystem.yaml
oc create -f ./rook/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
oc create -f ./rook/cluster/examples/kubernetes/ceph/csi/rbd/storageclass-test.yaml

```

5. [OPTIONAL] Make the `rook-cephfs` storage class as default if you want the PVC to bound with this type of storage

```
oc patch storageclass rook-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

6. Verify if the `rook-cephfs` is setup correctly

```console
# oc get pods -n rook-ceph
NAME                                                              READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-gbprl                                            3/3     Running     0          18h
csi-cephfsplugin-ksf4q                                            3/3     Running     0          18h
csi-cephfsplugin-p9zn8                                            3/3     Running     0          18h
csi-cephfsplugin-provisioner-847cc69bf7-kbp22                     6/6     Running     0          18h
csi-cephfsplugin-provisioner-847cc69bf7-sjw48                     6/6     Running     0          18h
csi-rbdplugin-cb698                                               3/3     Running     0          18h
csi-rbdplugin-dc769                                               3/3     Running     0          18h
csi-rbdplugin-provisioner-559d486946-9lmj6                        6/6     Running     0          18h
csi-rbdplugin-provisioner-559d486946-qzmkx                        6/6     Running     0          18h
csi-rbdplugin-xhsrs                                               3/3     Running     0          18h
rook-ceph-crashcollector-compute-00.aadeshpa.cp4waiops502.nj656   1/1     Running     0          18h
rook-ceph-crashcollector-compute-01.aadeshpa.cp4waiops502.58gdt   1/1     Running     0          18h
rook-ceph-crashcollector-compute-02.aadeshpa.cp4waiops502.g5759   1/1     Running     0          18h
rook-ceph-mds-myfs-a-f6f6786f5-4srzr                              1/1     Running     0          18h
rook-ceph-mds-myfs-b-59bfdc6cf-kxv5h                              1/1     Running     0          18h
rook-ceph-mgr-a-66d4b55f74-rc7vt                                  1/1     Running     0          18h
rook-ceph-mon-a-d68b969b6-xfdp7                                   1/1     Running     0          18h
rook-ceph-mon-b-5b885b65dc-v6nvs                                  1/1     Running     0          18h
rook-ceph-mon-d-57f65b889d-hgv5n                                  1/1     Running     0          18h
rook-ceph-operator-6db87d87d4-z2hrt                               1/1     Running     6          18h
rook-ceph-osd-0-7b69699c46-7t5j7                                  1/1     Running     0          18h
rook-ceph-osd-1-bbbbbf4-vnndc                                     1/1     Running     0          18h
rook-ceph-osd-2-7fdb4bbd84-62bmf                                  1/1     Running     0          18h
rook-ceph-osd-prepare-compute-00.aadeshpa.cp4waiops502.comqnvq7   0/1     Completed   0          18h
rook-ceph-osd-prepare-compute-01.aadeshpa.cp4waiops502.com825zw   0/1     Completed   0          18h
rook-ceph-osd-prepare-compute-02.aadeshpa.cp4waiops502.comxvd94   0/1     Completed   0          18h
```
```console
# oc get storageclass
NAME                    PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block         rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   18h
rook-cephfs (default)   rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   18h
```


### Steps to delete rook-cephfs Storage from the cluster.

NOTE : You should make sure that none of the PVC are bound to `rook-cephfs` storageclass, if it is then you need to delete the PVC first, else deletion of below resources puts finalizer on the resources.

Apply the above yamls in the given sequence :

```shell
oc patch storageclass rook-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
oc delete -f ./rook/cluster/examples/kubernetes/ceph/csi/rbd/storageclass-test.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/filesystem.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/cluster.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/common.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/crds.yaml

```

Once above resources are deleted follow this step to [Delete the data on hosts](https://rook.github.io/docs/rook/v1.5/ceph-teardown.html#delete-the-data-on-hosts) from `/var/lib/rook`

## Add an NFS Server to provide Persistent storage.

### Steps to setup

1. Download kubernetes-incubator

```console
$ curl -L -o kubernetes-incubator.zip https://github.com/kubernetes-incubator/external-storage/archive/master.zip
unzip kubernetes-incubator.zip
```
```shell
$ cd external-storage-master/nfs-client/
```

2. Mirror the image for setting up NFS server in your internal container registry

Example:

```shell
podman pull <original_image>
podman tag <original_image> <registry_hostname>:<registry_port>/<namspace>/<image:tag>
podman push <registry_hostname>:<registry_port>/<namspace>/<image:tag>

registry_hostname : your internal container registry hostname
registry_port : your internal container registry port
namespace : namespace as per the orignal image
image:tag : image name and its tag name

```

Repeat the above example commands `podman pull, tag and push` to mirror the below image from the given file

File : `deploy/deployment.yaml`

Image

```yaml
spec:
  serviceAccountName: nfs-client-provisioner
  containers:
    - name: nfs-client-provisioner
      image: quay.io/external_storage/nfs-client-provisioner:latest

```

3. Update the image url for the image in above mentioned file, by updating the original registry of the image with your internal container registry where you mirrored above image.

Example: For File `deploy/deployment.yaml`

```yaml
spec:
  serviceAccountName: nfs-client-provisioner
  containers:
    - name: nfs-client-provisioner
      image: <registry_hostname>:<registry_port>/external_storage/nfs-client-provisioner:latest
        
```

4. Follow the steps in [this article to setup the NFS storage](https://medium.com/faun/openshift-dynamic-nfs-persistent-volume-using-nfs-client-provisioner-fcbb8c9344e)

5. [OPTIONAL] Make the NFS Storage Class the default Storage Class if you want it to be the default storageclass 

  `oc patch storageclass managed-nfs-storage -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'`

