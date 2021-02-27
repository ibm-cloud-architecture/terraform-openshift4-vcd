# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }

locals {
    source_networks = [var.vcd_edge_gateway["network_name"]]
    rule_id = ""
  }

//provider "vcd" {
//  user                 = var.vcd_user
//  password             = var.vcd_password
//  org                  = var.vcd_org
//  url                  = var.vcd_url
//  max_retry_timeout    = 30
//  allow_unverified_ssl = true
//  logging              = true
//}

data "vcd_resource_list" "edge_gateway_name" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = "edge_gateway_name"
  resource_type = "vcd_edgegateway" # Finds all networks, regardless of their type
  list_mode     = "name"
}

# Shows the list of all networks with the corresponding import command
output "gateway_list" {
  value = data.vcd_resource_list.edge_gateway_name.list
}


resource "vcd_nsxv_firewall_rule" "lb_allow" {
// if airgapped, you need the lb to have access so it can get dhcpd, coredns and haproxy images
  count = var.airgapped["enabled"] ? 1 : 0 

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "${var.cluster_id}_lb_allow_rule"  
  
  source {
    ip_addresses = [var.network_lb_ip_address]
  }

  destination {
    ip_addresses = ["any"]
  }

  service {
    protocol = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "cluster_allow" {
// if airgapped, you need the lb to have access so it can get dhcpd, coredns and haproxy images
  count = var.airgapped["enabled"] ? 0 : 1 

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "${var.cluster_id}_cluster_allow_rule"  
  
  source {
    ip_addresses = flatten([var.network_lb_ip_address,var.cluster_ip_addresses])
  }

  destination {
    ip_addresses = ["any"]
  }

  service {
    protocol = "any"
  }

}

resource "vcd_nsxv_firewall_rule" "ocp_console_allow" {
// in case you have airgapped clusters and deny all rule in place we generate an exclusion 

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)

  action       = "accept"
  name         = "${var.cluster_id}_ocp_console_allow_rule"  
  
  source {
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [var.vcd_edge_gateway["cluster_public_ip"]]
  }

  service {
    protocol = "any"
  }
 
}

resource "vcd_nsxv_dnat" "dnat" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  var.vcd_edge_gateway["external_gateway_interface"] 
  network_type = "ext"
  
  original_address   = var.vcd_edge_gateway["cluster_public_ip"]
  translated_address = var.network_lb_ip_address
  protocol = "any"
  description = "${var.cluster_id} OCP Console DNAT Rule"
}

