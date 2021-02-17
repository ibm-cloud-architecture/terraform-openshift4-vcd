# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }

locals {
    source_networks = [var.vcd_edge_gateway["name"]]
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

resource "vcd_network_routed" "network_routed" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edge_gateway["edge_gateway"]
  name         = var.vcd_edge_gateway["name"]
  gateway      = var.vcd_edge_gateway["gateway"]
  interface_type  = "internal"
  static_ip_pool { 
       start_address = var.vcd_edge_gateway["static_start_address"]
       end_address   = var.vcd_edge_gateway["static_end_address"]
    }
}

resource "vcd_nsxv_firewall_rule" "deny_rule" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edge_gateway["edge_gateway"]
  action       = "deny"
  name         = "${var.cluster_id}_deny_rule"  
  
  source {
    org_networks = local.source_networks
  }

  destination {
    ip_addresses = ["any"]
  }

  service {
    protocol = "any"
  }
  depends_on = [vcd_network_routed.network_routed]
}

resource "vcd_nsxv_firewall_rule" "cluster_allow" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edge_gateway["edge_gateway"]
  above_rule_id = vcd_nsxv_firewall_rule.deny_rule.id
  action       = "accept"
  name         = "${var.cluster_id}_cluster_allow_rule"  
  
  source {
    ip_addresses = concat(var.bootstrap_ip_address,var.control_plane_ip_addresses,var.compute_ip_addresses)
  }

  destination {
    ip_addresses = ["any"]
  }

  service {
    protocol = "any"
  }
  depends_on = [vcd_network_routed.network_routed]
}

resource "vcd_nsxv_dnat" "dnat" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edge_gateway["edge_gateway"]
  network_name = "dal10-w02-tenant-external" 
  network_type = "ext"
  
  original_address   = var.cluster_public_ip
  translated_address = var.lb_ip_address
  protocol = "any"
  description = "${var.cluster_id} DNAT Rule"
  
  depends_on = [vcd_network_routed.network_routed]
}

