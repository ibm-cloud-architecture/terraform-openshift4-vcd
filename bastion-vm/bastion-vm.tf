
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
data "vcd_edgegateway" "mygateway" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name          = element(data.vcd_resource_list.edge_gateway_name.list,1)

}

 locals {
    ansible_directory = "/tmp"
    additional_trust_bundle_dest = dirname(var.additionalTrustBundle)
    pull_secret_dest = dirname(var.openshift_pull_secret)
    nginx_repo        = "${path.cwd}/bastion-vm/ansible"
    service_network_name      =  substr(var.vcd_url,8,3) == "dal" ? "dal10-w02-service02" : "fra04-w02-service01"
    external_network_name     =  substr(var.vcd_url,8,3) == "dal" ? "dal10-w02-tenant-external" : "fra04-w02-tenant-external"
    xlate_private_ip          =  element(data.vcd_edgegateway.mygateway.external_network_ips,1)
    xlate_public_ip           =  element(data.vcd_edgegateway.mygateway.external_network_ips,2)
    login_to_bastion          =  "Next Step login to Bastion via: ssh -i ~/.ssh/id_bastion root@${var.initialization_info["public_bastion_ip"]}" 
 }

resource "vcd_network_routed" "net" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name         = var.initialization_info["network_name"]
  interface_type = "internal"
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  gateway      = cidrhost(var.initialization_info["machine_cidr"], 1)

  static_ip_pool {
    start_address = var.initialization_info["static_start_address"]
    end_address   = var.initialization_info["static_end_address"]
  }
  
}

resource "vcd_nsxv_firewall_rule" "bastion_public_outbound_allow" {

  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  action       = "accept"
  name         = "bastion_outbound_public_allow_rule"  
  
  source {
    ip_addresses = [var.initialization_info["internal_bastion_ip"]]
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
    org_networks = [var.initialization_info["network_name"]]
  }
// temp code 

  destination {
    gateway_interfaces = [var.user_service_network_name == "" ? local.service_network_name : var.user_service_network_name]
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
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [var.initialization_info["public_bastion_ip"]]
  }

  service {
    protocol = "tcp"
    port     = "22"
  }
  service {
    protocol = "tcp"
    port     = "5000"
  }

    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}

resource "vcd_nsxv_dnat" "dnat" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
//  network_name =  local.external_network_name 
  network_name = var.user_tenant_external_network_name == "" ? local.external_network_name : var.user_tenant_external_network_name
  network_type = "ext"
  
  original_address   = var.initialization_info["public_bastion_ip"]
  translated_address = var.initialization_info["internal_bastion_ip"]
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
//  network_name = local.external_network_name
    network_name = var.user_tenant_external_network_name == "" ? local.external_network_name : var.user_tenant_external_network_name
  network_type = "ext"
  
  original_address   = var.initialization_info["machine_cidr"]
  translated_address = local.xlate_public_ip
  description = "Outbound Public SNAT Rule"
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}
resource "vcd_nsxv_snat" "snat_priv" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  var.user_service_network_name == "" ? local.service_network_name : var.user_service_network_name 
  network_type = "ext"
  
  original_address   = var.initialization_info["machine_cidr"]
  translated_address = local.xlate_private_ip
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
  name = "bastion-${var.vcd_vdc}-${var.cluster_id}"
}
# Associate the route network with the Vapp
resource "vcd_vapp_org_network" "vappOrgNet" {
   org          = var.vcd_org
   vdc          = var.vcd_vdc
   vapp_name         = vcd_vapp.bastion.name

   org_network_name  = var.initialization_info["network_name"]
   depends_on = [vcd_network_routed.net]
}
# Create the bastion VM
resource "vcd_vapp_vm" "bastion" { 
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  vapp_name     = vcd_vapp.bastion.name
  name          = "bastion-${var.vcd_vdc}-${var.cluster_id}"
  depends_on = [
    vcd_vapp_org_network.vappOrgNet,
    vcd_nsxv_dnat.dnat,
    vcd_nsxv_firewall_rule.bastion_inbound_allow,
    vcd_nsxv_snat.snat_priv,
    vcd_nsxv_snat.snat_pub,
  ]
  catalog_name  = var.vcd_catalog
  template_name = var.initialization_info["bastion_template"]
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  
  override_template_disk {
    bus_type           = "paravirtual"
    size_in_mb         = var.bastion_disk
    bus_number         = 0
    unit_number        = 0
}
  # Assign IP address on the routed network 
  network {
    type               = "org"
    name               = var.initialization_info["network_name"]
    ip_allocation_mode = "MANUAL"
    ip                 = var.initialization_info["internal_bastion_ip"]
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
  # upload the ssh key on the VM. it will avoid password authentification for later interaction with the vm

}
 

 data "template_file" "ansible_inventory" {
  template = <<EOF
${var.initialization_info["public_bastion_ip"]} ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/id_bastion ansible_user=root ansible_python_interpreter="/usr/libexec/platform-python" 
EOF
}

 data "template_file" "ansible_main_yaml" {
       template = file ("${path.module}/ansible/main.yaml.tmpl")
       
       vars ={
         vcd                  = var.vcd_vdc
         public_bastion_ip    = var.initialization_info["public_bastion_ip"]
         rhel_key      = var.initialization_info["rhel_key"]
         cluster_id    = var.cluster_id
         base_domain   = var.base_domain
         lb_ip_address = var.lb_ip_address
         openshift_version = var.openshift_version
         terraform_ocp_repo = var.initialization_info["terraform_ocp_repo"]
         nginx_repo_dir = local.nginx_repo
         openshift_pull_secret = var.openshift_pull_secret
         pull_secret_dest   = local.pull_secret_dest
         terraform_root = path.cwd
         additional_trust_bundle   =  var.additionalTrustBundle
         additional_trust_bundle_dest   = local.additional_trust_bundle_dest 
         run_cluster_install       =  var.initialization_info["run_cluster_install"]
         
       }
 }
 
resource "local_file" "ansible_inventory" {
  content  = data.template_file.ansible_inventory.rendered
  filename = "${local.ansible_directory}/inventory"
  depends_on = [
         null_resource.setup_ssh 
  ]
}

resource "local_file" "ansible_main_yaml" {
  content  = data.template_file.ansible_main_yaml.rendered
  filename = "${local.ansible_directory}/main.yaml"
  depends_on = [
         null_resource.setup_ssh 
  ]
}

resource "null_resource" "setup_bastion" {
   #launch ansible script. 

  
  provisioner "local-exec" {
      command = " ansible-playbook -i ${local.ansible_directory}/inventory ${local.ansible_directory}/main.yaml"
  }
  depends_on = [
      local_file.ansible_inventory,
      local_file.ansible_main_yaml,
  ]
}
resource "null_resource" "setup_ssh" {
 
  provisioner "local-exec" {
      command = templatefile("${path.module}/scripts/fix_ssh.sh.tmpl" , {
         bastion_password            = var.initialization_info["bastion_password"]
         public_bastion_ip           = var.initialization_info["public_bastion_ip"] 
    })
  }
    depends_on = [
        vcd_vapp_vm.bastion 
  ]
}

  data "local_file" "read_final_args" {
  filename = pathexpand("~/${var.cluster_id}info.txt")
  depends_on = [
    null_resource.setup_bastion
  ]
}

resource "local_file" "write_args" {
  content  = local.login_to_bastion
  filename = pathexpand("~/${var.cluster_id}info.txt")
  depends_on = [
         null_resource.setup_ssh 
  ]
}
