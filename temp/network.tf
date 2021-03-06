# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }

locals {
   datacenter = substr(var.vcd_url,8,3)
   vg_gateway = substr(var.vcd_url,8,3) == "dal" ? "dal" : "fra"
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
output "datacenter" {
  value = local.vg_gateway
}




data "vcd_resource_list" "edge_gateway_name" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = "edge_gateway-name"
  resource_type = "vcd_edgegateway" # Finds all networks, regardless of their type
  list_mode     = "name"
}

# Shows the list of all networks with the corresponding import command
output "gateway_list" {
  value = data.vcd_resource_list.edge_gateway_name.list
}

data "vcd_edgegateway" "mygateway" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = element(data.vcd_resource_list.edge_gateway_name.list,1)

}
locals {
     external_ip1 = element(data.vcd_edgegateway.mygateway.external_network_ips,1)
     external_ip2 = element(data.vcd_edgegateway.mygateway.external_network_ips,2)
     display_msg = "default external: ${data.vcd_edgegateway.mygateway.default_external_network_ip} external network ips: ${local.external_ip1} ,${local.external_ip2} "
}

# Shows the list of all networks with the corresponding import command
output "edge_gateway_id" {
  value = local.display_msg
}  

# Get the name of the default gateway from the data source
# and use it to establish a second data source
//data "vcd_external_network" "external_network1" {
//  name = data.vcd_edgegateway.mygateway.external_network.name 
//}

//# From the second data source we extract the basic networking info
//output "gateway" {
//  value = data.vcd_external_network.external_network1.ip_scope.0.gateway
//}









data "vcd_resource_list" "resource_list" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = "resource_list"
  resource_type = "resources" # Finds all networks, regardless of their type
  list_mode     = "name"
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
