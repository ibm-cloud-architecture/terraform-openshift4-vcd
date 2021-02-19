output "kubeadmin_user_info" {
  value = flatten (["kubeadmin", data.local_file.kubeadmin_password.content])
}  

output "kubeadmin_password" {
  value = data.local_file.kubeadmin_password.content
}

output "public_ip" {
  value = var.vcd_edge_gateway["cluster_public_ip"]
}

output "openshift_console_url" {
  value = local.openshift_console_url 
}

output "export_kubeconfig" {
  value = local.export_kubeconfig 
}