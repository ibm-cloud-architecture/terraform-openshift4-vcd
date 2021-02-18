# force local ignition provider binary
# provider "ignition" {
#   version = "0.0.0"
# }

locals {
  mirror_repo_ip      = [var.airgapped["mirror_ip"]]
  mirror_repo_fqdn    = [var.airgapped["mirror_fqdn"]]
  app_name            = "${var.cluster_id}-${var.base_domain}"
  vcd_net_name        = var.vcd_edge_gateway["network_name"]
  cluster_domain      = "${var.cluster_id}.${var.base_domain}"
  bootstrap_fqdns     = ["bootstrap-00.${local.cluster_domain}"]
  lb_fqdns            = ["lb-00.${local.cluster_domain}"]
  api_lb_fqdns        = formatlist("%s.%s", ["api-int", "api", "*.apps"], local.cluster_domain)
  rev_api_lb_fqdns       = formatlist("%s.%s", ["api-int", "api"], local.cluster_domain)
  control_plane_fqdns = [for idx in range(var.control_plane_count) : "control-plane-0${idx}.${local.cluster_domain}"]
  compute_fqdns       = [for idx in range(var.compute_count) : "compute-0${idx}.${local.cluster_domain}"]
  storage_fqdns       = [for idx in range(var.storage_count) : "storage-0${idx}.${local.cluster_domain}"]
  no_ignition         = ""
  repo_fqdn = var.airgapped["enabled"] ? local.mirror_repo_fqdn : []
  repo_ip = var.airgapped["enabled"] ? local.mirror_repo_ip : []
  openshift_console_url = "https://console-openshift-console.apps.${var.cluster_id}.${var.base_domain}"

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

resource "vcd_vapp_org_network" "vappOrgNet" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  vapp_name         = local.app_name
  org_network_name  = var.vcd_edge_gateway["network_name"]
  depends_on = [vcd_vapp.app_name]
}


resource "vcd_vapp" "app_name" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  name = local.app_name

}

resource "tls_private_key" "installkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
  
  depends_on = [vcd_vapp_org_network.vappOrgNet]
}

resource "local_file" "write_private_key" {
  content         = tls_private_key.installkey.private_key_pem
  filename        = "${path.cwd}/installer/${var.cluster_id}/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = tls_private_key.installkey.public_key_openssh
  filename        = "${path.cwd}/installer/${var.cluster_id}/openshift_rsa.pub"
  file_permission = 0600
}

module "network" {
  source        = "./network"
  cluster_ip_addresses = flatten ([
      var.bootstrap_ip_address,
      var.control_plane_ip_addresses,
      var.compute_ip_addresses,
      var.storage_ip_addresses
      ])
  airgapped     = var.airgapped   
  network_lb_ip_address = var.lb_ip_address
  vcd_password  = var.vcd_password
  vcd_org       = var.vcd_org
  vcd_vdc       = var.vcd_vdc
  cluster_id    = var.cluster_id
  vcd_edge_gateway = var.vcd_edge_gateway
   
  depends_on = [
     local_file.write_public_key
  ]
}
module "lb" {
  count = var.create_loadbalancer_vm ? 1 : 0
  source        = "./lb"
  lb_ip_address = var.lb_ip_address

  api_backend_addresses = flatten([
    var.bootstrap_ip_address,
    var.control_plane_ip_addresses
  ])

  ingress_backend_addresses = concat(var.compute_ip_addresses, var.storage_ip_addresses)
  ssh_public_key            = chomp(tls_private_key.installkey.public_key_openssh)

  cluster_domain = local.cluster_domain

  bootstrap_ip      = var.bootstrap_ip_address
  control_plane_ips = var.control_plane_ip_addresses

  dns_addresses = var.create_loadbalancer_vm ? concat([var.lb_ip_address],local.mirror_repo_ip,var.vm_dns_addresses) : var.vm_dns_addresses


  dns_ip_addresses = zipmap(
    concat(
      local.repo_fqdn,
      local.bootstrap_fqdns,
      local.api_lb_fqdns,
      local.control_plane_fqdns,
      local.compute_fqdns,
      local.storage_fqdns
    ),
    concat(
      local.repo_ip,
      list(var.bootstrap_ip_address),
      [for idx in range(length(local.api_lb_fqdns)) : var.lb_ip_address],
      var.control_plane_ip_addresses,
      var.compute_ip_addresses,
      var.storage_ip_addresses
    )
 ) 

  rev_dns_ip_addresses = zipmap(
    concat(
      local.repo_fqdn,
      local.bootstrap_fqdns,
      local.rev_api_lb_fqdns,
      local.control_plane_fqdns,
      local.compute_fqdns,
      local.storage_fqdns
    ),
    concat(
      local.repo_ip,
      list(var.bootstrap_ip_address),
      [for idx in range(length(local.rev_api_lb_fqdns)) : var.lb_ip_address],
      var.control_plane_ip_addresses,
      var.compute_ip_addresses,
      var.storage_ip_addresses
    )
 ) 
  dhcp_ip_addresses = zipmap(
    concat(
      local.bootstrap_fqdns,
      local.control_plane_fqdns,
      local.compute_fqdns,
      local.storage_fqdns
    ),
    concat(
      list(var.bootstrap_ip_address),
      var.control_plane_ip_addresses,
      var.compute_ip_addresses,
      var.storage_ip_addresses
    )
 ) 

  mac_prefix = var.mac_prefix
  cluster_id  = var.cluster_id
   
  loadbalancer_ip   = var.loadbalancer_lb_ip_address
  loadbalancer_cidr = var.loadbalancer_lb_machine_cidr

  hostnames_ip_addresses  = zipmap(local.lb_fqdns, [var.lb_ip_address])
  machine_cidr            = var.machine_cidr
  network_id              = var.vcd_edge_gateway["network_name"]
  loadbalancer_network_id = var.loadbalancer_network 

   vcd_catalog             = var.vcd_catalog
   lb_template             = var.lb_template
  
   num_cpus                = 2
   vcd_vdc                 = var.vcd_vdc
   vcd_org                 = var.vcd_org 
   app_name                = local.app_name
   
   depends_on = [
      module.network
  ]
}
module "ignition" {
  source              = "./ignition"
  ssh_public_key      = chomp(tls_private_key.installkey.public_key_openssh)
  base_domain         = var.base_domain
  cluster_id          = var.cluster_id
  cluster_cidr        = var.openshift_cluster_cidr
  cluster_hostprefix  = var.openshift_host_prefix
  cluster_servicecidr = var.openshift_service_cidr
  machine_cidr        = var.machine_cidr
  pull_secret         = var.openshift_pull_secret
  openshift_version   = var.openshift_version
  total_node_count    = var.compute_count + var.storage_count
  airgapped           = var.airgapped   
  depends_on = [
     local_file.write_public_key,
     module.network
  ]
 }
 
module "bootstrap" {
  source = "./vm"
  mac_prefix = var.mac_prefix
  count = var.create_vms_only ? 0 : 1

  ignition = module.ignition.append-bootstrap
  hostnames_ip_addresses = zipmap(
    local.bootstrap_fqdns,
    [var.bootstrap_ip_address]
  )

  create_vms_only = var.create_vms_only
  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template
  num_cpus      = 2
  memory        = 8192
  disk_size    = var.bootstrap_disk
  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
  depends_on = [
   module.network
  ]
}
module "bootstrap_vms_only" {
  source = "./vm"
  mac_prefix = var.mac_prefix
  count = var.create_vms_only ? 1 : 0
  ignition = local.no_ignition 
  hostnames_ip_addresses = zipmap(
    local.bootstrap_fqdns,
    [var.bootstrap_ip_address]
  )

  create_vms_only = var.create_vms_only
  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template
  num_cpus      = 2
  memory        = 8192
  disk_size    = var.bootstrap_disk
  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
  depends_on = [
   module.ignition
  ]
}


module "control_plane_vm" {
  source = "./vm"
  mac_prefix = var.mac_prefix
  hostnames_ip_addresses = zipmap(
    local.control_plane_fqdns,
    var.control_plane_ip_addresses
  )
  
  create_vms_only = var.create_vms_only
  count = var.create_vms_only ? 0 : 1
  ignition = module.ignition.master_ignition
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template


  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr

  num_cpus      = var.control_plane_num_cpus
  memory        = var.control_plane_memory
  disk_size    = var.control_disk

  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
//   depends_on = [
//     module.bootstrap
//   ]  
}
module "control_plane_vm_vms_only" {
  source = "./vm"
  mac_prefix = var.mac_prefix
  hostnames_ip_addresses = zipmap(
    local.control_plane_fqdns,
    var.control_plane_ip_addresses
  )
  count = var.create_vms_only ? 1 : 0
  create_vms_only = var.create_vms_only
  ignition = local.no_ignition 
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template


  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr

  num_cpus      = var.control_plane_num_cpus
  memory        = var.control_plane_memory
  disk_size    = var.control_disk

  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
  depends_on = [
    module.bootstrap
  ]  
}

module "compute_vm" {
  source = "./vm"
  mac_prefix = var.mac_prefix
  hostnames_ip_addresses = zipmap(
    local.compute_fqdns,
    var.compute_ip_addresses
  )
  create_vms_only = var.create_vms_only
  count = var.create_vms_only ? 0 : 1
  ignition = module.ignition.worker_ignition

  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template

  num_cpus      = var.compute_num_cpus
  memory        = var.compute_memory
  disk_size    = var.compute_disk

  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
//     depends_on = [
//       module.control_plane_vm
//   ]
}
module "compute_vm_vms_only" {
  source = "./vm"
  mac_prefix = var.mac_prefix
  hostnames_ip_addresses = zipmap(
    local.compute_fqdns,
    var.compute_ip_addresses
  )
  create_vms_only = var.create_vms_only
  count = var.create_vms_only ? 1 : 0
  ignition = local.no_ignition

  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template

  num_cpus      = var.compute_num_cpus
  memory        = var.compute_memory
  disk_size    = var.compute_disk

  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
    depends_on = [
      module.control_plane_vm
  ]
}

module "storage_vm" {
  source = "./storage"
  mac_prefix = var.mac_prefix 
  hostnames_ip_addresses = zipmap(
    local.storage_fqdns,
    var.storage_ip_addresses
  )
  create_vms_only = var.create_vms_only
  count = var.create_vms_only ? 0 : 1
  ignition =  module.ignition.worker_ignition
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template

  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr

  num_cpus      = var.storage_num_cpus
  memory        = var.storage_memory
  disk_size     = var.compute_disk 
  extra_disk_size    = var.storage_disk
  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
//  depends_on = [
//      module.control_plane_vm
//  ]
}
module "storage_vm_vms_only" {
  source = "./storage"
  mac_prefix = var.mac_prefix 
  hostnames_ip_addresses = zipmap(
    local.storage_fqdns,
    var.storage_ip_addresses
  )
  create_vms_only = var.create_vms_only
  count = var.create_vms_only ? 1 : 0
  ignition = local.no_ignition
  network_id              = var.vcd_edge_gateway["network_name"]
  vcd_catalog             = var.vcd_catalog
  vcd_vdc                 = var.vcd_vdc
  vcd_org                 = var.vcd_org 
  app_name                = local.app_name
  rhcos_template          = var.rhcos_template

  cluster_domain = local.cluster_domain
  machine_cidr   = var.machine_cidr

  num_cpus      = var.storage_num_cpus
  memory        = var.storage_memory
  disk_size     = var.compute_disk 
  extra_disk_size    = var.storage_disk
  dns_addresses = var.create_loadbalancer_vm ? [var.lb_ip_address] : var.vm_dns_addresses
  depends_on = [
      module.control_plane_vm
   ]
}
  data "local_file" "kubeadmin_password" {
  filename = "${path.cwd}/installer/${var.cluster_id}/auth/kubeadmin-password"
  depends_on = [
    module.ignition
  ]
}
