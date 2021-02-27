//////
// vSphere variables
//////


variable "vcd_vdc" {
  type        = string
  description = "This is the vcd vdc for the environment."
}
variable "vcd_user" {
  type        = string
  description = "This is the vcd user."
}
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

variable "routed_net"{
  type        = string
  description = "name of the routed network used"
  }

variable "internal_bastion_ip"{
  type        = string
  description = "ip of bastion on routed network"
}
variable "bastion_ip"{
  type        = string
  description = "external ip of the bastion"
}
variable "bastion_template"{
  type        = string
  description = "name of the template used to create the bastion vm"
  default     = "RedHat-8-Template-Official"
}

variable "template_catalog"{
  type        = string
  description = "name of tempalte catalog"
  default     = "Public Catalog" 
}

variable "bastion_password"{
  type        = string
  description = "password of the bastion vm"
}

// Network object
variable "vcd_network_routed" {
  type = object ({
    gateway = string
    static_ip_start = string
    static_ip_end   = string
  })
  default = {
    gateway          = "192.16.0.1"
    static_ip_start  = "192.16.0.11"
    static_ip_end    = "192.16.0.18"
    
  }
}
