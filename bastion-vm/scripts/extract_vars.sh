#!/bin/bash

# Create th variables file used by ansible
if [ -z ./bastion-vm/ansible/ansible_vars.json ]
then 
    rm -f ./bastion-vm/ansible/ansible_vars.json
fi 
# the variable values are extracted from terraform.tfvars file
echo "{" > ./bastion-vm/ansible/ansible_vars.json
echo "    \"rhel_key\":" $(echo $(cat $1 | grep rhel_key| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}')) "," >> ./bastion-vm/ansible/ansible_vars.json
echo "    \"ocp_cluster\":" $(echo $(cat $1 | grep ocp_cluster| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}')) "," >> ./bastion-vm/ansible/ansible_vars.json
echo "    \"ocp_version\":" $(echo $(cat $1 | grep ocp_version| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}')) "," >> ./bastion-vm/ansible/ansible_vars.json
echo "    \"domain\":" $(echo $(cat $1 | grep domain| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}')) "," >> ./bastion-vm/ansible/ansible_vars.json
echo "    \"lb_ip\":" $(echo $(cat $1 | grep lb_ip| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}')) "," >> ./bastion-vm/ansible/ansible_vars.json
echo "    \"terraform_ocp_repo\":" $(echo $(cat $1 | grep terraform_ocp_repo| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}')) >> ./bastion-vm/ansible/ansible_vars.json
echo "}" >> ./bastion-vm/ansible/ansible_vars.json

# Create the inventory file used by ansible 
if [ -z ./bastion-vm/ansible/inventory ]
then 
    rm -f ./bastion-vm/ansible/inventory
fi
# the IP of bastion vm is extracted from terraform.tfvars file
echo $(echo $(cat $1 | grep bastion_ip| awk 'BEGIN {getline my_line; gsub(" ", "", my_line); print my_line}'| awk 'BEGIN {FS = "="} ;{ print $2}' | awk 'BEGIN {getline my_line; gsub("\"", "", my_line); print my_line}')) "ansible_connection=ssh ansible_user=root ansible_python_interpreter=\"/usr/libexec/platform-python\" " > ./bastion-vm/ansible/inventory
