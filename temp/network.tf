# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }

locals {
 //   edge_name = data.vcd_resource_list.list_of_nets.list
//    rule_id = ""
  }

provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = var.vcd_org
  url                  = var.vcd_url
  max_retry_timeout    = 30
  allow_unverified_ssl = true
  logging              = true
}


data "vcd_resource_list" "list_of_gateway" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = "list_of_nets"
  resource_type = "vcd_edgegateway" # Finds all networks, regardless of their type
  list_mode     = "name"
}

# Shows the list of all networks with the corresponding import command
output "gateway_list" {
  value = data.vcd_resource_list.list_of_gateway.list
}

data "vcd_resource_list" "edge_gateway_name" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = "edge_gateway_name"
  resource_type = "vcd_edgegateway" # Finds all networks, regardless of their type
  list_mode     = "name"
}

# Shows the list of all networks with the corresponding import command
output "gateway_name" {
  value = data.vcd_resource_list.edge_gateway_name.list
}
resource "vcd_network_routed" "net" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name         = "mynet"
  edge_gateway = element(data.vcd_resource_list.list_of_gateway.list,1)
  gateway      = "10.10.0.1"

  dhcp_pool {
    start_address = "10.10.0.2"
    end_address   = "10.10.0.100"
  }

  static_ip_pool {
    start_address = "10.10.0.152"
    end_address   = "10.10.0.254"
  }
  
}
