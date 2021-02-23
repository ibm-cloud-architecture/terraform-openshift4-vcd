
# Create a Vapp (needed by the VM)
resource "vcd_vapp" "bastion" {
  name = "bastion"
}
# Associate the route network with the Vapp
resource "vcd_vapp_org_network" "vappOrgNet" {
   vapp_name         = vcd_vapp.bastion.name

   org_network_name  = var.routed_net
}
# Create the bastion VM
resource "vcd_vapp_vm" "bastion" { 
  vapp_name     = vcd_vapp.bastion.name
  name          = "bastion"
  depends_on = [
    vcd_vapp_org_network.vappOrgNet,
  ]
  catalog_name  = var.template_catalog
  template_name = var.bastion_template
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  guest_properties = {
    "guest.hostname" = "bastion"
  }
  metadata = {
    role    = "bastion"
    env     = "ocp"
    version = "v1"
  }
  # Assign IP address on the routed network 
  network {
    type               = "org"
    name               = var.routed_net
    ip_allocation_mode = "MANUAL"
    ip                 = var.internal_bastion_ip
    is_primary         = true
    connected          = true
  }
  # define Password for the vm. The the script could use it to do the ssh-copy-id to upload the ssh key
   customization {
    allow_local_admin_password = true 
    auto_generate_password = false
    admin_password = var.bastion_password
  }
  power_on = true
  # upload the ssh key on the VM. it will avoid password authentification for later interaction with the vm
  provisioner "local-exec" {
    command = "sshpass -p ${var.bastion_password} ssh-copy-id -f root@${var.bastion_ip} -f"
  }
  # extract from terraform.tfvars file the values to create ansible inventory and varaible files.
  provisioner "local-exec"  {
    command = "./bastion-vm/scripts/extract_vars.sh terraform.tfvars" 
  }
  #launch ansible script. 
  provisioner "local-exec" {
      command = " ansible-playbook -i ./bastion-vm/ansible/inventory ./bastion-vm/ansible/main.yaml" 
  }
}