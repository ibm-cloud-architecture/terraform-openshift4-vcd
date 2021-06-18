#Followed this document to script this automated script for setting up simple private registry
#https://www.redhat.com/sysadmin/simple-container-registry


# This parameter is to be set in case of the registry to be setup with existing TLS CERT file like `domain.crt`
export REGISTRY_SETUP_WITH_EXISTING_TLS_CERTIFICATE="false"

#These parameters needs to be set for setting up the registry
export registry_dir="/opt/test2_registry"
export AUTH_DIR="$registry_dir/auth"
export CERTS_DIR="$registry_dir/certs"
export DATA_DIR="$registry_dir/data"

# Cert filenames, in case if you dont have one use the name '$HOSTNAME-$REGISTRY_PORT_NUMBER.crt' and '$HOSTNAME-$REGISTRY_PORT_NUMBER.key'
export REGISTRY_HTTP_TLS_KEY_FILENAME="bastion-cp4waiops-registry-cp4waiops-shared-registry-cluster-5004.key"
export REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME="bastion-cp4waiops-registry-cp4waiops-shared-registry-cluster-5004.crt"

# Registry accessing credentials
export registry_username_to_be_created="test_user"
export registry_password_to_be_set="simplepassword"
export REGISTRY_PORT_NUMBER="5004"

#This is the auth file tht gets created for your registry credentials
auth_filename="htpasswd_$REGISTRY_PORT_NUMBER"

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

#Checking if existing TLS cert file 
if [[ "$REGISTRY_SETUP_WITH_EXISTING_TLS_CERTIFICATE" == "true" ]]; then
   
   echo "[INFO] Registry setup is starting where TLS CERTIFICATE is already existing"
   if [[ ( -f "$CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME" ) && ( -f "$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME" ) ]]; then
      echo "[INFO] The REGISTRY_HTTP_TLS_KEY_FILEPATH=$CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME and REGISTRY_HTTP_TLS_CERTIFICATE_FILEPATH=$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME exists for registry setup."
      
      echo "[INFO] Generate credentials for accessing the registry once it is setup"
      echo "[INFO] Username as provided : $registry_username_to_be_created"
      echo "[INFO] Password as provided : $registry_password_to_be_set"

      if [ ! -d "$AUTH_DIR" ]; then
         mkdir -p $AUTH_DIR
      fi
      htpasswd -bBc $AUTH_DIR/$auth_filename $registry_username_to_be_created $registry_password_to_be_set
      
      echo "[INFO] The certificate will also have to be trusted by your hosts and clients"
      echo "[INFO] Copying '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' to directory '/etc/pki/ca-trust/source/anchors/'"
      cp $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME /etc/pki/ca-trust/source/anchors/
      echo "[INFO] Updating the ca trust"
      update-ca-trust

      echo "[INFO] Printing the trust list with hostname=$HOSTNAME"
      echo "Trust List : $(trust list | grep -i $HOSTNAME)"

      echo "[INFO] Starting  the registry"
      podman run --name registry_$REGISTRY_PORT_NUMBER \
      -p $REGISTRY_PORT_NUMBER:5000 \
      -v $DATA_DIR:/var/lib/registry:z \
      -v $AUTH_DIR:/auth:z \
      -e "REGISTRY_AUTH=htpasswd" \
      -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
      -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd_$REGISTRY_PORT_NUMBER \
      -v $CERTS_DIR:/certs:z \
      -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME" \
      -e "REGISTRY_HTTP_TLS_KEY=/certs/$REGISTRY_HTTP_TLS_KEY_FILENAME" \
      -e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
      -d \
      docker.io/library/registry:latest

      if [ $? -gt 0 ]; then
         echo "[ERROR] Some error while runnng the registry setup command, please check container logs and try again"
         exit 1
      fi


     firewall-cmd --add-port=$REGISTRY_PORT_NUMBER/tcp --zone=internal --permanent
     firewall-cmd --add-port=$REGISTRY_PORT_NUMBER/tcp --zone=public --permanent
     firewall-cmd --reload

     echo "[INFO] Registry container started :"
     echo "[INFO] ================================================================================================================"
     podman ps
     echo "[INFO] ================================================================================================================"
  

     registry_container_id=$(podman ps --format "{{.ID}}")
     echo "registry_container_id=$registry_container_id"

     #echo "[INFO] Restarting the registry container"
     #podman restart $registry_container_id

     if [ $? -gt 0 ]; then
        echo "[ERROR] Some issue in setting up your registry"
        exit 1
     else
        echo "[INFO] Your registry was setup successfully"
        echo "[INFO] ================================================================================================================"
        echo "[INFO] Registry Information to access it from client machine"
        echo "[INFO] ================================================================================================================"
        echo "[INFO] Registry crt file is present in directory path :  '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' "
        echo "[INFO] This crt file can be copied to the client machine at path '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' from where you want to login to this registry"
        echo "[INFO] You need to execute these commands on client where you want to login to this registry"
        echo "[INFO] 'cp $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME /etc/pki/ca-trust/source/anchors/'"
        echo "[INFO] 'update-ca-trust'"
        echo "[INFO] Verify the ca trust list is updated successfully by command :"
        echo "[INFO] trust list | grep -i \"$HOSTNAME\""
        echo "[INFO] ================================================================================================================"
        echo "[INFO] You can login finally to the registry with command 'GODEBUG=x509ignoreCN=0 podman login $HOSTNAME:$REGISTRY_PORT_NUMBER -u $registry_username_to_be_created -p $registry_password_to_be_set --cert-dir \"/etc/pki/ca-trust/source/anchors/\"' "
        echo "[INFO] ================================================================================================================"
     fi



   else
      echo "[ERROR] The REGISTRY_HTTP_TLS_KEY_FILEPATH=$REGISTRY_HTTP_TLS_KEY_FILEPATH or REGISTRY_HTTP_TLS_CERTIFICATE_FILEPATH=$REGISTRY_HTTP_TLS_CERTIFICATE_FILEPATH does not exists, please verify if the file paths for these files are correct and if the files are present, and then try again. "
      exit 1
   fi
else
  # setup with new Certificate
  echo "[INFO] Registry setup is starting where TLS CERTIFICATE is to be created newly as self signed certificate"
  
  echo "[INFO] Creating directories $registry_dir/{auth,certs,data} if it does not exists"
  if [ ! -d "$registry_dir" ]; then
     mkdir -p $registry_dir
  fi
 
  mkdir -p $registry_dir/{auth,certs,data}
  
  echo "[INFO] Generate credentials for accessing the registry"
  echo "[INFO] Username as provided : $registry_username_to_be_created"
  echo "[INFO] Password as provided : $registry_password_to_be_set"
  htpasswd -bBc $AUTH_DIR/$auth_filename $registry_username_to_be_created $registry_password_to_be_set   

  if [[ ( -f "$CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME" ) && ( -f "$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME" ) ]]; then
     echo "[WARNING] The certificate files $CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME and $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME already exists"
     read -p "Do you want to use existing certificate files for setting up this registry('Y/N' or 'y/n'): "  userinput
      if [[ ( $userinput == "Y" ) || ( $userinput == "y" ) ]];then
         echo "[INFO] Using the existing certificate files '$CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME' and '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME'"
      elif [[ ( $userinput == "N" ) || ( $userinput == "n" ) ]];then
         echo "[INFO] Common Name to be used for registry tls key and cert :--------->>>>>> Hostname='$HOSTNAME' <<<<<<<---------"

         echo "[INFO] The registry is secured with TLS by using a key and certificate signed by a simple self-signed certificate. "
         echo "[INFO] Creating self-signed certificate in directory $CERTS_DIR"
         openssl req -newkey rsa:4096 -nodes -sha256 -keyout $CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME -x509 -days 365 -out $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME      
      else
         echo "[ERROR] Invalid option '$userinput', please run again and select ('Y/N' or 'y/n')"
         exit 1
      fi

  fi
  
  echo "[INFO] The certificate will also have to be trusted by your hosts and clients"
  echo "[INFO] Copying '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' to directory '/etc/pki/ca-trust/source/anchors/'"
  cp $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME /etc/pki/ca-trust/source/anchors/
  echo "[INFO] Updating the ca trust"
  update-ca-trust

  echo "[INFO] Printing the trust list with hostname=$HOSTNAME"
  echo "Trust List : $(trust list | grep -i $HOSTNAME)"
  
  echo "[INFO] Starting  the registry"
  podman run --name registry_$REGISTRY_PORT_NUMBER \
  -p $REGISTRY_PORT_NUMBER:5000 \
  -v $DATA_DIR:/var/lib/registry:z \
  -v $AUTH_DIR:/auth:z \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd_$REGISTRY_PORT_NUMBER \
  -v $CERTS_DIR:/certs:z \
  -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME" \
  -e "REGISTRY_HTTP_TLS_KEY=/certs/$REGISTRY_HTTP_TLS_KEY_FILENAME" \
  -e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
  -d \
  docker.io/library/registry:latest

  firewall-cmd --add-port=$REGISTRY_PORT_NUMBER/tcp --zone=internal --permanent
  firewall-cmd --add-port=$REGISTRY_PORT_NUMBER/tcp --zone=public --permanent
  firewall-cmd --reload

  echo "[INFO] Registry container started :"
  echo "[INFO] ================================================================================================================"
  podman ps
  echo "[INFO] ================================================================================================================"


  registry_container_id=$(podman ps --format "{{.ID}}")
  echo "registry_container_id=$registry_container_id"

  #echo "[INFO] Restarting the registry container"
  # podman restart $registry_container_id

  if [ $? -gt 0 ]; then
     echo "[ERROR] Some issue in setting up your registry"
     exit 1
  else
     echo "[INFO] Your registry was setup successfully"
     echo "[INFO] ================================================================================================================"
     echo "[INFO] Registry Information to access it from client machine"
     echo "[INFO] ================================================================================================================"
     echo "[INFO] Registry crt file is present in directory path :  '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' "
     echo "[INFO] This crt file can be copied to the client machine at path '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' from where you want to login to this registry"
     echo "[INFO] You need to execute these commands on client where you want to login to this registry"
     echo "[INFO] 'cp $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME /etc/pki/ca-trust/source/anchors/'"
     echo "[INFO] 'update-ca-trust'"
     echo "[INFO] Verify the ca trust list is updated successfully by command :"
     echo "[INFO] trust list | grep -i \"$HOSTNAME\""
     echo "[INFO] ================================================================================================================"
     echo "[INFO] You can login finally to the registry with command 'GODEBUG=x509ignoreCN=0 podman login $HOSTNAME:$REGISTRY_PORT_NUMBER -u $registry_username_to_be_created -p $registry_password_to_be_set --cert-dir \"/etc/pki/ca-trust/source/anchors/\"' "
     echo "[INFO] ================================================================================================================"
  fi
fi
