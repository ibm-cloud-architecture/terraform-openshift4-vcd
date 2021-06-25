rook_ceph_images_url=("docker.io/rook/ceph:v1.5.8"
            "docker.io/ceph/ceph:v15.2.9"
            "quay.io/cephcsi/cephcsi:v3.2.0"
            "k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.0.1"
            "k8s.gcr.io/sig-storage/csi-resizer:v1.0.0"
            "k8s.gcr.io/sig-storage/csi-provisioner:v2.0.0"
            "k8s.gcr.io/sig-storage/csi-snapshotter:v3.0.0"
            "k8s.gcr.io/sig-storage/csi-attacher:v3.0.0")

# This is your mirror registry where you want to mirror the strimzi images
mirror_registry="<mirror-registry>:<port>"

#Provide the creds for your mirror registry
mirror_registry_username="username"
mirror_registry_password="password"

echo "Trying to login to the mirror registry $mirror_registry"
podman login -u $mirror_registry_username -p $mirror_registry_password $mirror_registry --tls-verify=false
if [ $? -gt 0 ]; then
   echo "[ERROR] Some error occured while login to the mirror registry $mirror_registry"
   exit 1
fi

for image in ${rook_ceph_images_url[@]}; do
    echo "[INFO] Mirroring the image: $image"
    podman pull $image --tls-verify=false

    updated_image=""
    if [[ $image == *"docker.io"* ]]; then
       echo "Updating the $image with docker.io"
       updated_image="$(echo $image | sed 's|docker.io|'"$mirror_registry"'|g')"
    elif [[ $image == *"quay.io"* ]]; then
       echo "Updating the $image with quay.io"
       updated_image="$(echo $image | sed 's|quay.io|'"$mirror_registry"'|g')"
    elif [[ $image == *"k8s.gcr.io"* ]]; then  
       echo "Updating the $image with k8s.gcr.io"
       updated_image="$(echo $image | sed 's|k8s.gcr.io|'"$mirror_registry"'|g')"   
    fi 
 
    echo "[INFO] Tagging image $image to $updated_image"
    podman tag $image $updated_image
    echo "[INFO] Pushing image $updated_image to your mirror repository "
    podman push $updated_image --tls-verify=false
done


if [ -d "rook" ]; then
   rm -rf rook
fi
echo "[INFO] git cloning the repository rook --branch v1.5.8"
git clone https://github.com/rook/rook --branch v1.5.8


#updating all the image registry to mirror registry
sed -i 's|rook/ceph:|'"$mirror_registry"'/rook/ceph:|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|quay.io|'"$mirror_registry"'|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|k8s.gcr.io|'"$mirror_registry"'|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|ceph/ceph:|'"$mirror_registry"'/ceph/ceph:|g' rook/cluster/examples/kubernetes/ceph/cluster.yaml


#uncommenting the env variables for image
sed -i 's|# ROOK_CSI_CEPH_IMAGE|ROOK_CSI_CEPH_IMAGE|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|# ROOK_CSI_REGISTRAR_IMAGE|ROOK_CSI_REGISTRAR_IMAGE|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|# ROOK_CSI_RESIZER_IMAGE|ROOK_CSI_RESIZER_IMAGE|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|# ROOK_CSI_PROVISIONER_IMAGE|ROOK_CSI_PROVISIONER_IMAGE|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|# ROOK_CSI_SNAPSHOTTER_IMAGE|ROOK_CSI_SNAPSHOTTER_IMAGE|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sed -i 's|# ROOK_CSI_ATTACHER_IMAGE|ROOK_CSI_ATTACHER_IMAGE|g' rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml

echo "[INFO] Applying the yamls to setup rook-cephfs storage"
oc apply -f ./rook/cluster/examples/kubernetes/ceph/crds.yaml

oc apply -f ./rook/cluster/examples/kubernetes/ceph/common.yaml
oc apply -f ./rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
oc apply -f ./rook/cluster/examples/kubernetes/ceph/cluster.yaml
oc apply -f ./rook/cluster/examples/kubernetes/ceph/filesystem.yaml
oc apply -f ./rook/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
oc apply -f ./rook/cluster/examples/kubernetes/ceph/csi/rbd/storageclass-test.yaml

if [ $? -gt 0 ]; then
   echo "[ERROR] Some issue occured while setting up yamls for rook-cephfs storage"
   exit 1
else
   echo "[INFO] rook-cephfs storage setup completed, please verify all the pods are running with command 'oc get pods -n rook-ceph' "
fi 
