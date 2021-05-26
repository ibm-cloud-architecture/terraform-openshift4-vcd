# Setup persistent storage for Airgap cluster


## Create rook-cephfs Storage for persistent storage.


### Pre-requisite

 - You need to have separate hard disk storage present for all the master nodes and compute nodes for `rook-cephfs` to work.
 - The separate hard disk storage capacity depends on your requirements, we setup 200GB hard disk storage for each master and comput node of the cluster.
 
### Steps to setup rook-cephfs

You can setup `rook-cephfs` storage in your airgap cluster by following below steps:

1. Clone the repository for rook, we have tested with the `--branch v1.5.8` which works correctly in OCP cluster 4.6 and that is airgapped.

```
git clone https://github.com/rook/rook --branch v1.5.8
```

2. Mirror the below images manually into your internal registry if you are using above version, else you would need to find the correct images as per given files from the cloned repository.

Example:

```
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

```
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

```
spec:
  cephVersion:
    image: docker.io/ceph/ceph:v15.2.9

```



3. Update the image urls for all the images in above mentioned files, by updating the original registry of the image with your internal container registry where you mirrored above images.

Example: For File `rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml`

```
spec:
  serviceAccountName: rook-ceph-system
  containers:
  - name: rook-ceph-operator
    image: <registry_hostname>:<registry_port>/rook/ceph:v1.5.8
        
```
NOTE: Make sure all the above mentioned images in above point has been updated in the given yaml files, before moving ahead.


4. Finally apply all the yaml files as shown below to setup the `rook-cephfs` storage

```
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

```
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



# oc get storageclass
NAME                    PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block         rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   18h
rook-cephfs (default)   rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   18h
```


### Steps to delete rook-cephfs Storage from the cluster.

NOTE : You should make sure that none of the PVC are bound to `rook-cephfs` storageclass, if it is then you need to delete the PVC first, else deletion of below resources puts finalizer on the resources.

Apply the above yamls in the given sequence :

```
oc patch storageclass rook-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
oc delete -f ./rook/cluster/examples/kubernetes/ceph/csi/rbd/storageclass-test.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/filesystem.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/cluster.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/common.yaml
oc delete -f ./rook/cluster/examples/kubernetes/ceph/crds.yaml

```


## Add an NFS Server to provide Persistent storage.

### Steps to setup

1. Download kubernetes-incubator

```
$ curl -L -o kubernetes-incubator.zip https://github.com/kubernetes-incubator/external-storage/archive/master.zip
unzip kubernetes-incubator.zip
$ cd external-storage-master/nfs-client/

```

2. Mirror the image for setting up NFS server in your internal container registry

Example:

```
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

```
spec:
  serviceAccountName: nfs-client-provisioner
  containers:
    - name: nfs-client-provisioner
      image: quay.io/external_storage/nfs-client-provisioner:latest

```

3. Update the image url for the image in above mentioned file, by updating the original registry of the image with your internal container registry where you mirrored above image.

Example: For File `deploy/deployment.yaml`

```
spec:
  serviceAccountName: nfs-client-provisioner
  containers:
    - name: nfs-client-provisioner
      image: <registry_hostname>:<registry_port>/external_storage/nfs-client-provisioner:latest
        
```

4. Follow the steps in [this article to setup the NFS storage](https://medium.com/faun/openshift-dynamic-nfs-persistent-volume-using-nfs-client-provisioner-fcbb8c9344e)



5. [OPTIONAL] Make the NFS Storage Class the default Storage Class if you want it to be the default storageclass 

  `oc patch storageclass managed-nfs-storage -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'`

