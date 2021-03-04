
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
 locals {
    ansible_directory = "/tmp"
    nginx_repo        = "${path.cwd}/ansible"
    service_network_name      =  substr(var.vcd_url,8,3) == "dal" ? "dal10-w02-service02" : "fra04-w02-service01"
    external_network_name     =  substr(var.vcd_url,8,3) == "dal" ? "dal10-w02-tenant-external" : "fra04-w02-tenant-external"
    xlate_ip                  =  substr(var.vcd_url,8,3) == "dal" ? "52.117.132.198" :  "52.117.132.220"
 }
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
  name         = var.vcd_edge_gateway["network_name"]
  interface_type = "internal"
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  gateway      = cidrhost(var.machine_cidr, 1)

  static_ip_pool {
    start_address = var.vcd_edge_gateway["static_start_address"]
    end_address   = var.vcd_edge_gateway["static_end_address"]
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
    org_networks = [var.vcd_edge_gateway["network_name"]]
  }

  destination {
    gateway_interfaces = [local.service_network_name]
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
    ip_addresses = [var.public_bastion_ip]
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
  network_name =  local.external_network_name 
  network_type = "ext"
  
  original_address   = var.public_bastion_ip
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
  network_name = local.external_network_name
  network_type = "ext"
  
  original_address   = var.machine_cidr
  translated_address = var.public_bastion_ip
  description = "Outbound Public SNAT Rule"
    depends_on = [
      vcd_vapp_org_network.vappOrgNet,
  ]
}
resource "vcd_nsxv_snat" "snat_priv" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = element(data.vcd_resource_list.edge_gateway_name.list,1)
  network_name =  local.service_network_name 
  network_type = "ext"
  
  original_address   = var.machine_cidr
  translated_address = local.xlate_ip
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

   org_network_name  = var.vcd_edge_gateway["network_name"]
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
    vcd_nsxv_dnat.dnat,
    vcd_nsxv_firewall_rule.bastion_inbound_allow,
    vcd_nsxv_snat.snat_priv,
    vcd_nsxv_snat.snat_pub,
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
    name               = var.vcd_edge_gateway["network_name"]
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

}
 

 data "template_file" "ansible_inventory" {
  template = <<EOF
${var.public_bastion_ip}
 ansible_connection=ssh ansible_user=root ansible_python_interpreter="/usr/libexec/platform-python" 
EOF
}

 data "template_file" "ansible_main_yaml" {
       template = file ("${path.module}/ansible/main.yaml.tmpl")
       
       vars ={
         public_bastion_ip    = var.public_bastion_ip
         rhel_key      = var.rhel_key
         cluster_id    = var.cluster_id
         base_domain   = var.base_domain
         lb_ip_address = var.lb_ip_address
         openshift_version = var.openshift_version
         terraform_ocp_repo = var.terraform_ocp_repo
         nginx_repo_dir = local.nginx_repo
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
      command = templatefile("${path.module}/scripts/fix_ssh.sh.tmpl", {
         bastion_password     = var.bastion_password
         public_bastion_ip           = var.public_bastion_ip 
    })
  }
    depends_on = [
        vcd_vapp_vm.bastion 
  ]
}