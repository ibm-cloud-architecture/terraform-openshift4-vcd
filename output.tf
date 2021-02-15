
output "kubeadmin_password" {
  value = data.local_file.kubeadmin_password.content
}
