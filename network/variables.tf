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
//variable "vcd_url" {
//  type        = string
//  description = "This is the vcd url for the environment."
//}
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


variable "vcd_edge_gateway" {
  type = map(string)
  default = {
    edge_gateway = ""
    gateway      = ""
    network_name         = ""
    static_start_address  = ""
    static_end_address    = ""
    cluster_public_ip     = ""
  }
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

