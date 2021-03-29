variable "hostnames_ip_addresses" {
  type = map(string)
}

variable "ignition" {
  type    = string
  default = ""
}

variable "mac_prefix" {
  type    = string
  default = ""
}

variable "rhcos_template" {
  type    = string
  default = ""
}


variable "vcd_vdc"     {
  type = string
}

variable "vcd_org"     {
  type = string
}

variable "app_name"    {
  type=string
}


variable "vcd_catalog"  {
  type = string
}
variable "cluster_domain" {
  type = string
}


variable "machine_cidr" {
  type = string
}

variable "memory" {
  type = string
}

variable "num_cpus" {
  type = string
}

variable "dns_addresses" {
  type = list(string)
}

variable "disk_size" {
  type    = number
  default = 60
}

variable "extra_disk_size" {
  type    = number
  default = 0
}

variable "nested_hv_enabled" {
  type    = bool
  default = false
}

variable "network_id" {
  type = string
}
variable "create_vms_only" {
  type = bool
  default = false
}
// variable "staticip_file_vm" {
//  type = string
// }

variable "initialization_info" {
  type = object ({
    public_bastion_ip      = string
    bastion_password       = string
    internal_bastion_ip    = string
    terraform_ocp_repo     = string  
    rhel_key               = string
    machine_cidr           = string
    network_name           = string
    static_start_address   = string
    static_end_address     = string
    bastion_template       = string
    run_cluster_install    = bool
  })
}
