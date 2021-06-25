#Followed this document to script this automated script for setting up simple private registry
#https://www.redhat.com/sysadmin/simple-container-registry

#############################################################################################
                 #Parameters that needs to be set before running the script#
#############################################################################################
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
#############################################################################################

#This is the auth file that gets created for your registry credentials. This is static and no need to change.
auth_filename="htpasswd_$REGISTRY_PORT_NUMBER"


validate_pre_requisite_tools(){

  echo "[INFO] Checking Pre-requisites:"
  if podman -v > /dev/null ;then
     echo "[INFO] Pre-requisite 'Podman' exists"
  else
     echo "[ERROR] Pre-requisite 'Podman' does not exists, please install and try again"
     exit 1
  fi

  echo "[INFO] Installing httpd-tools"
  yum install -y podman httpd-tools

}

registry_password_setup(){

  echo "[INFO] Generate credentials for accessing the registry"
  echo "[INFO] Username as provided : $registry_username_to_be_created"
  echo "[INFO] Password as provided : $registry_password_to_be_set"
  htpasswd -bBc $AUTH_DIR/$auth_filename $registry_username_to_be_created $registry_password_to_be_set

}

setup_firewall_for_exposed_port(){

     firewall-cmd --add-port=$REGISTRY_PORT_NUMBER/tcp --zone=internal --permanent
     firewall-cmd --add-port=$REGISTRY_PORT_NUMBER/tcp --zone=public --permanent
     firewall-cmd --reload

}

start_container_registry(){

      echo "[INFO] Starting  the registry"
      podman run --name $REGISTRY_NAME \
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
         echo "[ERROR] Some error while running the registry setup command, please check container logs and try again"
         exit 1
      fi

}

restart_container_registry(){

     echo "[INFO] Registry container started :"
     echo "[INFO] ================================================================================================================"
     podman ps
     echo "[INFO] ================================================================================================================"

     registry_container_id=$(podman ps -aqf "name=$REGISTRY_NAME")
     echo "registry_container_id=$registry_container_id"

     echo "[INFO] Restarting the registry container"
     podman restart $registry_container_id

     if [ $? -gt 0 ]; then
       echo "[ERROR] Some issue in restarting your registry, please check container logs and try again"
       exit 1
     fi
}

display_registry_access_details(){


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

}



#echo "[INFO] Checking Pre-requisites:"
#if podman -v > /dev/null ;then
#   echo "[INFO] Pre-requisite 'Podman' exists"
#else
#   echo "[ERROR] Pre-requisite 'Podman' does not exists, please install and try again"
#   exit 1
#fi

#if httpd-tools -v > /dev/null ;then
#   echo "[INFO] Pre-requisite 'httpd-tools' exists"
#else
#   echo "[ERROR] Pre-requisite 'httpd-tools' does not exists, installing it."
#   yum install -y podman httpd-tools
#fi

#installing httpd-tools
#echo "[INFO] Installing httpd-tools"
#yum install -y podman httpd-tools

validate_pre_requisite_tools

#Checking if existing TLS cert file 
if [[ "$REGISTRY_SETUP_WITH_EXISTING_TLS_CERTIFICATE" == "true" ]]; then
   
   echo "[INFO] Registry setup is starting where TLS CERTIFICATE is already existing"
   if [[ ( -f "$CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME" ) && ( -f "$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME" ) ]]; then
      echo "[INFO] The REGISTRY_HTTP_TLS_KEY_FILEPATH=$CERTS_DIR/$REGISTRY_HTTP_TLS_KEY_FILENAME and REGISTRY_HTTP_TLS_CERTIFICATE_FILEPATH=$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME exists for registry setup."
      
      if [ ! -d "$AUTH_DIR" ]; then
         mkdir -p $AUTH_DIR
      fi
      registry_password_setup

      echo "[INFO] The certificate will also have to be trusted by your hosts and clients"
      echo "[INFO] Copying '$CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME' to directory '/etc/pki/ca-trust/source/anchors/'"
      cp $CERTS_DIR/$REGISTRY_HTTP_TLS_CERTIFICATE_FILENAME /etc/pki/ca-trust/source/anchors/
      echo "[INFO] Updating the ca trust"
      update-ca-trust

      echo "[INFO] Printing the trust list with hostname=$HOSTNAME"
      echo "Trust List : $(trust list | grep -i $HOSTNAME)"

      start_container_registry

      setup_firewall_for_exposed_port

      restart_container_registry
      if [ $? -gt 0 ]; then
         echo "[ERROR] Some issue in setting up your registry"
         exit 1
      else
         display_registry_access_details
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
  
  registry_password_setup

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
  
  start_container_registry

  setup_firewall_for_exposed_port

  restart_container_registry  
  if [ $? -gt 0 ]; then
     echo "[ERROR] Some issue in setting up your registry"
     exit 1
  else
     display_registry_access_details
  fi

fi
