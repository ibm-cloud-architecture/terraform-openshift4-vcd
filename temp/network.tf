# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }



provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = var.vcd_org
  url                  = var.vcd_url
  max_retry_timeout    = 30
  allow_unverified_ssl = true
  logging              = true
}



resource "vcd_vapp_vm" "bastion" { 
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  vapp_name     = "bastion-${var.vcd_vdc}-${var.cluster_id}"
  name          = "test-${var.vcd_vdc}-${var.cluster_id}"
  catalog_name  = var.vcd_catalog
  template_name = var.initialization_info["bastion_template"]
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  guest_properties = {
    "guest.hostname" = "test-${var.vcd_vdc}-${var.cluster_id}"
  }
  metadata = {
    role    = "bastion"
    env     = "ocp"
    version = "v1"
  }
  # Assign IP address on the routed network 
  network {
    type               = "org"
    name               = var.initialization_info["network_name"]
    ip_allocation_mode = "MANUAL"
    ip                 = "172.16.0.110"
    is_primary         = true
    connected          = true
  }
  # define Password for the vm. The the script could use it to do the ssh-copy-id to upload the ssh key
   customization {
    allow_local_admin_password = true 
    auto_generate_password = false
    admin_password = var.initialization_info["bastion_password"]
  }
  power_on = true

}


//# Shows the list of all networks with the corresponding import command
//output "resource_list" {
//  value = data.vcd_resource_list.resource_list.list
//}
//resource "vcd_network_routed" "net" {
//  org          = var.vcd_org
//  vdc          = var.vcd_vdc
//  name         = "mynet"
//  edge_gateway = element(data.vcd_resource_list.list_of_gateway.list,1)
//  gateway      = "10.10.0.1"
//
//  dhcp_pool {
//    start_address = "10.10.0.2"
//    end_address   = "10.10.0.100"
//  }
//
//  static_ip_pool {
//    start_address = "10.10.0.152"
//    end_address   = "10.10.0.254"
//  }
//  
//}
