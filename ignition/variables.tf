variable "base_domain" {
  type = string
}

variable "cluster_cidr" {
  type = string
}

variable "cluster_hostprefix" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "cluster_servicecidr" {
  type = string
}

variable "machine_cidr" {
  type = string
}

variable "master_cpu" {
  type    = string
  default = 8
}

variable "master_disk_size" {
  type    = string
  default = 120
}

variable "master_memory" {
  type    = string
  default = 32768
}

variable "pull_secret" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "openshift_version" {
  type    = string
  default = "4.6"
}

variable "total_node_count" {
  type = number
}

variable "storage_fqdns" {
  type = list(string)   
}

variable "storage_count" {
  type = number
  default = 0
}

variable "airgapped"  {
  type        = map(string)
  description = "test  variable for airgapped instead of separate vars"
  default     =  {
         enabled   = false
         ocp_rel_ver = ""
         mirror_ip   = ""
         mirror_fqdn = ""
         mirror_port = ""
         mirror_repository = ""
         additionalTrustBundle = ""
         }
}

variable "openshift_installer_url" {
  type    = string
  default = "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp"
}

variable "proxy_config" {
  type = map(string)
  default = {
    enabled               = false
    httpProxy             = ""
    httpsProxy            = ""
    noProxy               = ""
  }
}