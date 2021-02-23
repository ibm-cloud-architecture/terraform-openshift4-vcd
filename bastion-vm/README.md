# Provison and configure the bastion VM

This module provisions the bastion VM then it configure it. 

The provision ensure that the VM is attached to the route networkd using for the installation.

Due to an issue with RHEL 8 template provided by VCD library, the VM is created suing RHEL 7 official image. 

The configuation tasks include:

* RHEL subscription enablement 
* DNS configuration
* tools (oc, git terraform ) installation
* Nginx 

## requirements

a ssh key available in $HOME/.ssh directory

ansible installed on the environment where the script is launch

terraforms.tfvars populated with the varaible needed by the ansible script. 

## how to use the module

Inside your main terraform file, you could call the module to launch its execution.

Sample of bastion-vm module calling
```
module "bastion-vm" {
  source =  "./bastion-vm"
  routed_net = var.routed_net
  internal_bastion_ip = var.internal_bastion_ip
  bastion_template = var.bastion_template
  template_catalog = var.template_catalog
  bastion_password = var.bastion_password
  bastion_ip = var.bastion_ip
}
```

## Flow  of the module

The bastion-vm has the following flow:

1. Create a Vapp
2. Associate the Vapp with routed network
3. Create the VM from the teample then customize it with static IP on routed network and password
4. Upload the ssh key ($HOME/.ssh/id_rsa.pub)
5. Launch script to extract values from terraforms.tfvars to populate `./bastion-vm/ansible/ansible_vars.json` variables file and `./bastion/ansible/inventory inventory` file.

## Needed variables 

The extraction script need to find these elements into the terraform.tfvars file:

name | description | sample value
---- | ----------- | ------------
rhel_key | the RHEL entitlment key to register the bastion VM  | look of the VCD console to get it
ocp_cluster | name of the ocp cluster | ocp
ocp_version |  version of the ocp cluster |  4.6
domain | domain of the ocp cluster | mydomain.com
lb_ip | IP address of the load balancer if front of OCP | 172.16.0.19
terraform_ocp_repo | url of the git repo containing the terraform script to install OCP | https://github.com/slipsibm/terraform-openshift4-vmware
bastion_ip | IP address of the bastion VM (external IP : one of the 5 public IP) | X.X.X.X


In addition, the module will also use the follwoing variable
name | description | default value
---- | ----------- | ------------
bastion_password  | the temporary password used before the load of ssh key | ########
template_catalog |  the catalog where the template is located | Public Catalog
bastion_template |  the nale of the template usd to create the bastion VM | RedHat-7-Template-Official
internal_bastion_ip |  the IP address of Bastion VM on routed network | 172.16.0.10
routed_net |  the name of the routed network |  ocpnet


