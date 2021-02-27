
provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = var.vcd_org
  url                  = var.vcd_url
  max_retry_timeout    = 30
  allow_unverified_ssl = true
  logging              = true
}
#retrieve edge gateway name

data "vcd_resource_list" "edge_gateway_name" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = "edge_gateway_name"
  resource_type = "vcd_edgegateway" # find gateway name
  list_mode     = "name"
}

resource "vcd_network_routed" "net" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name         = var.routed_net
  interface_type = "internal"
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  gateway      = var.vcd_network_routed["gateway"]

  static_ip_pool {
    start_address = var.vcd_network_routed["static_ip_start"]
    end_address   = var.vcd_network_routed["static_ip_end"]
  }
  
}

resource "vcd_nsxv_firewall_rule" "bastion_public_outbound_allow" {

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "bastion_outbound_public_allow_rule"  
  
  source {
    ip_addresses = [var.internal_bastion_ip]
  }

  destination {
    ip_addresses = ["any"]
  }

  service {
    protocol = "any"
  }
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}

resource "vcd_nsxv_firewall_rule" "bastion_private_outbound_allow" {

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "bastion_outbound_private_allow_rule"  
  
  source {
    org_networks = [var.routed_net]
  }

  destination {
    gateway_interfaces = ["dal10-w02-service02"]
  }

  service {
    protocol = "any"
  }
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}

resource "vcd_nsxv_firewall_rule" "bastion_inbound_allow" {

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "bastion_inbound_allow_rule"  
  
  source {
    ip_addresses = ["Any"]
  }

  destination {
    ip_addresses = [var.bastion_ip]
  }

  service {
    protocol = "tcp"
    port     = "22"
  }
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}

resource "vcd_nsxv_dnat" "dnat" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  var.routed_net 
  network_type = "org"
  
  original_address   = var.bastion_ip
  translated_address = var.internal_bastion_ip
  protocol = "any"
  description = "Bastion DNAT Rule"
 
  depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}

resource "vcd_nsxv_snat" "snat_pub" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  "dal10-w02-tenant-external" 
  network_type = "ext"
  
  original_address   = "192.16.0.1/24"
  translated_address = var.bastion_ip
  description = "Outbound Public SNAT Rule"
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}
resource "vcd_nsxv_snat" "snat_priv" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  "dal10-w02-service02" 
  network_type = "ext"
  
  original_address   = "192.16.0.1/24"
  translated_address = "52.117.132.198"
  description = "Outbound Private SNAT Rule"
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}


# Shows the list of all networks with the corresponding import command
//output "gateway_list" {
//  value = data.vcd_resource_list.edge_gateway_name.list
//}
# Create a Vapp (needed by the VM)
resource "vcd_vapp" "bastion" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name = "bastion"
}
# Associate the route network with the Vapp
resource "vcd_vapp_org_network" "vappOrgNet" {
   org          = var.vcd_org
   vdc          = var.vcd_vdc
   vapp_name         = vcd_vapp.bastion.name

   org_network_name  = var.routed_net
   depends_on = [vcd_network_routed.net]
}
# Create the bastion VM
resource "vcd_vapp_vm" "bastion" { 
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  vapp_name     = vcd_vapp.bastion.name
  name          = "testbastion"
  depends_on = [
    vcd_vapp_org_network.vappOrgNet,
  ]
  catalog_name  = var.template_catalog
  template_name = var.bastion_template
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  guest_properties = {
    "guest.hostname" = "testbastion"
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