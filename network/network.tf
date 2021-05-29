# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }

locals {
    source_networks = [var.initialization_info["network_name"]]
    ansible_directory = "/tmp"
//    external_network_name     =  substr(var.vcd_url,8,3) == "dal" ? "dal10-w02-tenant-external" : "fra04-w02-tenant-external"
      external_network_name     =  var.user_tenant_external_network_name

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

resource "vcd_nsxv_firewall_rule" "mirror_allow" {
// if airgapped, you need to allow access to mirrors public ip
  count = var.airgapped["enabled"] ? 1 : 0 

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "${var.cluster_id}_mirror_allow_rule"  
  
  source {
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [var.airgapped["mirror_ip"]]
  }

  service {
    protocol = "tcp"
    port     = var.airgapped["mirror_port"]
  }
}

resource "vcd_nsxv_firewall_rule" "cluster_allow" {
// if not airgapped, you need the cluster to have access because the default is deny
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
    ip_addresses = [var.cluster_public_ip]
  }

  service {
    protocol = "any"
  }
 
}

resource "vcd_nsxv_dnat" "dnat" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  local.external_network_name 
  network_type = "ext"
  
  original_address   = var.cluster_public_ip
  translated_address = var.network_lb_ip_address
  protocol = "any"
  description = "${var.cluster_id} OCP Console DNAT Rule"
}

 data "template_file" "ansible_add_entries_bastion" {
  template = <<EOF
---
- hosts: localhost
  connection: local
  gather_facts: False
  tasks:
    - name: update /etc/hosts
      blockinfile:
         path: /etc/hosts
         block: |
            ${var.network_lb_ip_address}  api.${var.cluster_id}.${var.base_domain}
            ${var.network_lb_ip_address}  api-int.${var.cluster_id}.${var.base_domain}
         %{if var.airgapped["enabled"]}
            ${var.airgapped["mirror_ip"]}  ${var.airgapped["mirror_fqdn"]} 
         %{endif}
            
         state: present
         marker_begin: "${var.cluster_id}"
         marker_end: "${var.cluster_id}"
         
    - name: update dnsmasq
      blockinfile: 
         path: /etc/dnsmasq.conf
         block: |
            address=/.apps.${var.cluster_id}.${var.base_domain}/${var.network_lb_ip_address}
         state: present
         marker_begin: "${var.cluster_id}"
         marker_end: "${var.cluster_id}"  
         
 %{if var.airgapped["enabled"]}
    - name: Copy Mirro Cert for trust
      shell: "cp ${var.additionalTrustBundle} /etc/pki/ca-trust/source/anchors/."
      args:
        warn: no  
    - name: Update trust cert store for mirror ca
      shell: "update-ca-trust"
      args:
        warn: no          
 %{endif}       
EOF
}

resource "local_file" "ansible_add_entries_bastion" {
  content  = data.template_file.ansible_add_entries_bastion.rendered
  filename = "${local.ansible_directory}/add_entries.yaml"
}


 data "template_file" "ansible_net_inventory" {
  template = <<EOF
${var.initialization_info["internal_bastion_ip"]} ansible_connection=ssh ansible_user=root ansible_python_interpreter="/usr/libexec/platform-python" 
EOF
}
 
resource "local_file" "ansible_net_inventory" {
  content  = data.template_file.ansible_net_inventory.rendered
  filename = "${local.ansible_directory}/inventory"
} 
 data "template_file" "ansible_remove_entries_bastion" {
  template = <<EOF
---
- hosts: localhost
  connection: local
  gather_facts: False
  vars:
     myvars: "{{ lookup('file', './ansible_vars.json') }}"
  tasks:
    - name: update hosts
      blockinfile:
         path: /etc/hosts
         block: |
            ${var.network_lb_ip_address}  api.${var.cluster_id}.${var.base_domain}
            ${var.network_lb_ip_address}  api-int.${var.cluster_id}.${var.base_domain}
         state: absent
         marker_begin: "${var.cluster_id}"
         marker_end: "${var.cluster_id}"        
    - name: update dnsmasq
      blockinfile: 
         path: /etc/dnsmasq.conf
         block: |
            address=/.apps.${var.cluster_id}.${var.base_domain}/${var.network_lb_ip_address}
         state: absent
         marker_begin: "${var.cluster_id}"
         marker_end: "${var.cluster_id}"         
EOF
}

resource "local_file" "ansible_remove_entries_bastion" {
  content  = data.template_file.ansible_remove_entries_bastion.rendered
  filename = "${local.ansible_directory}/remove_entries.yaml"
}


resource "null_resource" "update_bastion_files" {
   #launch ansible script. 
    provisioner "local-exec" {
      when = create
      command = " ansible-playbook -i ${local.ansible_directory}/inventory ${local.ansible_directory}/add_entries.yaml"
  }
//    provisioner "local-exec" {
//      when = destroy
//      command = " ansible-playbook -i ${local.ansible_directory}/inventory ${local.ansible_directory}/remove_entries.yaml"
//  } 
  depends_on = [
      local_file.ansible_add_entries_bastion,
      local_file.ansible_remove_entries_bastion,
  ]
}


         
