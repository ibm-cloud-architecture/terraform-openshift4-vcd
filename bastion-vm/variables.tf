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
  description = "nema of the template used to create the bastion vm"
  default     = "RedHat-7-Template-Official"
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


