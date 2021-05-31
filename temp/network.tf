# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }



provider "vcd" {
  user                 = "admin"
  password             = "vFAxlAFv67mB6U7IP"
  org                  = "17fd2ae4659245be9020424350a59e9c"
  url                  = "https://daldir01.vmware-solutions.cloud.ibm.com/api"
  vdc          = "vdc-dal10-tsts1"
  max_retry_timeout    = 30
  allow_unverified_ssl = true
  logging              = true
}


#retrieve edge gateway name

data "vcd_resource_list" "edge_gateway_name" {
  org          = "17fd2ae4659245be9020424350a59e9c"
  vdc          = "vdc-dal10-tsts1"
  name          = "edge_gateway_name"
  resource_type = "vcd_edgegateway" # find gateway name
  list_mode     = "name"
}
data "vcd_edgegateway" "mygateway" {
  org          = "17fd2ae4659245be9020424350a59e9c"
  vdc          = "vdc-dal10-tsts1"
  name          = element(data.vcd_resource_list.edge_gateway_name.list,1)

}

// temp code
data "vcd_resource_list" "list_of_resources" {
  org          = "17fd2ae4659245be9020424350a59e9c"
  vdc          = "vdc-dal10-tsts1"
  name = "list_of_resources"
  resource_type = "resources"
//  list_mode = "name"
}
output "gateway_name" {
   value = data.vcd_edgegateway.mygateway.name
}
output "resource_list" {
   value = data.vcd_resource_list.list_of_resources.list
}

data "vcd_resource_list" "edge_network_names" {
  name = "edge_network_names"
  resource_type = "vcd_external_network_v2"
  list_mode = "name"
}
output "network_names" {
   value = data.vcd_resource_list.edge_network_names.list
}
//output "gateway" {
//  value = data.vcd_external_network_v2.external_network1.ip_scope.0.gateway
//}
// end temp code
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
