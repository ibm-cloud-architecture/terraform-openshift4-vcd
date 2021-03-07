//////
// vSphere variables
//////


variable "vcd_vdc" {
  type        = string
  description = "This is the vcd vdc for the environment."
}

//variable "vcd_user" {
//  type        = string
//  description = "This is the vcd user."
//}
variable "vcd_password" {
  type        = string
  description = "This is the vcd password for the environment."
}
variable "vcd_org" {
  type        = string
  description = "This is the vcd org string from the console for the environment."
}
variable "vcd_url" {
  type        = string
  description = "This is the vcd url for the environment."
}
variable "vcd_catalog" {
  type        = string
  description = "This is the vcd catalog to use for the environment."
  default     = "Public Catalog"
}
variable "cluster_id" {
  type        = string
}

variable "network_lb_ip_address" {
  type        = string
}

variable "cluster_ip_addresses" {
  type        = list(string)
}

variable "cluster_public_ip" {
  type        = string
}

variable "base_domain" {
  type        = string
}

variable "airgapped"  {
  type        = map(string)
  description = "test  variable for airgapped instead of separate vars"
  default     =  {
         enabled   = false
         mirror_ip   = ""
         mirror_fqdn = ""
         mirror_port = ""
         mirror_repository = ""
         additionalTrustBundle = ""         
         }
}

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
    run_cluster_install    = bool
    
  })
}