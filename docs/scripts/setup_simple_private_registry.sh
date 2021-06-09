#Followed this document to script this automated script for setting up simple private registry
#https://www.redhat.com/sysadmin/simple-container-registry

registry_username_to_be_created="<username you want>"
registry_password_to_be_set="<password you want>"

registry_dir="/opt/registry"

cert_key_file="$HOSTNAME.key"
cert_crt_file="$HOSTNAME.crt"

echo "[INFO] Checking Pre-requisites:"
if podman -v > /dev/null ;then
   echo "[INFO] Pre-requisite 'Podman' exists"
else
   echo "[ERROR] Pre-requisite 'Podman' does not exists, please install and try again"
   exit 1
fi

#installing httpd-tools
echo "[INFO] Installing httpd-tools"
yum install -y podman httpd-tools

echo "[INFO] Creating directories $registry_dir/{auth,certs,data} if it does not exists"
if [ ! -d "$registry_dir" ]; then
   mkdir -p $registry_dir
fi
mkdir -p $registry_dir/{auth,certs,data}

echo "[INFO] Generate credentials for accessing the registry"
echo "[INFO] Username as provided : $registry_username_to_be_created"
echo "[INFO] Password as provided : $registry_password_to_be_set"
htpasswd -bBc /opt/registry/auth/htpasswd $registry_username_to_be_created $registry_password_to_be_set

echo "[INFO] Navigating to directory $registry_dir"
cd $registry_dir

echo "[INFO] Common Name to be used for registry tls key and cert :--------->>>>>> Hostname='$HOSTNAME' <<<<<<<---------"

echo "[INFO] The registry is secured with TLS by using a key and certificate signed by a simple self-signed certificate. "
echo "[INFO] Creating self-signed certificate in directory $registry_dir/certs"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout $registry_dir/certs/$cert_key_file -x509 -days 365 -out $registry_dir/certs/$cert_crt_file

echo "[INFO] The certificate will also have to be trusted by your hosts and clients"
echo "[INFO] Copying '$registry_dir/certs/$cert_crt_file' to directory '/etc/pki/ca-trust/source/anchors/'"
cp $registry_dir/certs/$cert_crt_file /etc/pki/ca-trust/source/anchors/

echo "[INFO] Updating the ca trust"
update-ca-trust

echo "[INFO] Printing the trust list with hostname=$HOSTNAME"
echo "Trust List : $(trust list | grep -i $HOSTNAME)"

echo "[INFO] Starting  the registry"
podman run --name myregistry \
-p 5000:5000 \
-v $registry_dir/data:/var/lib/registry:z \
-v $registry_dir/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v $registry_dir/certs:/certs:z \
-e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/$cert_crt_file" \
-e "REGISTRY_HTTP_TLS_KEY=/certs/$cert_key_file" \
-e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
-d \
docker.io/library/registry:latest

echo "[INFO] Registry container started :"
echo "[INFO] ================================================================================================================"
podman ps
echo "[INFO] ================================================================================================================"
   
firewall-cmd --add-port=5000/tcp --zone=internal --permanent
firewall-cmd --add-port=5000/tcp --zone=public --permanent
firewall-cmd --reload

registry_container_id=$(podman ps --format "{{.ID}}")
echo "registry_container_id=$registry_container_id"

echo "[INFO] Restarting the registry container"
podman restart $registry_container_id

if [ $? -gt 0 ]; then
   echo "[ERROR] Some issue in setting up your registry"
   exit 1
else
   echo "[INFO] Your registry was setup successfully"
   echo "[INFO] ================================================================================================================"
   echo "[INFO] Registry Information to access it from client machine"
   echo "[INFO] ================================================================================================================"
   echo "[INFO] Registry crt file is present in directory path :  '$registry_dir/certs/$cert_crt_file' "
   echo "[INFO] This crt file can be copied to the client machine at path '$registry_dir/certs/$cert_crt_file' from where you want to login to this registry"
   echo "[INFO] You need to execute these commands on client where you want to login to this registry"
   echo "[INFO] 'cp $registry_dir/certs/$cert_crt_file /etc/pki/ca-trust/source/anchors/'"
   echo "[INFO] 'update-ca-trust'"
   echo "[INFO] Verify the ca trues list is updated successfully by command :"
   echo "[INFO] trust list | grep -i \"$HOSTNAME\""
   echo "[INFO] ================================================================================================================"
   echo "[INFO] You can login finally to the registry with command 'GODEBUG=x509ignoreCN=0 podman login $HOSTNAME:5000 -u $registry_username_to_be_created -p $registry_password_to_be_set --cert-dir \"/etc/pki/ca-trust/source/anchors/\"' "
   echo "[INFO] ================================================================================================================"
 
fi
