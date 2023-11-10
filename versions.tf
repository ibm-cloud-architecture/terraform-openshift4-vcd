terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    tls = {
      source = "hashicorp/tls"
    }
    vsphere = {
      source = "hashicorp/vsphere"
    }
    vcd = {
      source = "vmware/vcd"
      version = "3.7.0"
  }
    ignition = {
       source = "community-terraform-providers/ignition"
       version = "2.1.6"
    }
  }
  required_version = ">= 0.13"
}
