
locals {
  installerdir = "${path.cwd}/installer/${var.cluster_id}"
  openshift_installer_url = "${var.openshift_installer_url}/latest-${var.openshift_version}"
  bootstrap_ignition_url = "http://${var.initialization_info["internal_bastion_ip"]}/installer/${var.cluster_id}/bootstrap.ign"
  mirror_fqdn = var.airgapped["mirror_fqdn"]
  mirror_port = var.airgapped["mirror_port"]
  mirror_repository = var.airgapped["mirror_repository"]
  module_path = path.module
}

resource "null_resource" "download_binaries" {
    triggers = {
      always_run = "$timestamp()"
  }
  provisioner "local-exec" {
    when = create
   command = templatefile("${path.module}/scripts/download.sh.tmpl", {
      installer_workspace  = local.installerdir
      installer_url        = local.openshift_installer_url
      airgapped_enabled    = var.airgapped["enabled"]
      airgapped_fqdn       = var.airgapped["mirror_fqdn"]
      airgapped_port       = var.airgapped["mirror_port"]
      airgapped_repository = var.airgapped["mirror_repository"]
      pull_secret          = var.pull_secret	
      ocp_ver_rel          = var.airgapped["ocp_ver_rel"]
      path_root            = path.cwd
    })
  }

//  provisioner "local-exec" {
//    when    = destroy
//      command = templatefile("${local.module_path}/scripts/destroy.sh.tmpl", { 
//      installer_workspace = local.installerdir
//    })
//  }
}

resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/manifests.sh.tmpl", {
      installer_workspace = local.installer_workspace
      path_root            = path.cwd
      path_module          = path.module
    })
  }
}

resource "null_resource" "generate_ignition" {
  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
    null_resource.generate_manifests,
    #local_file.cluster-dns-02-config,
    local_file.cluster_scheduler,
  ]
  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/ignition.sh.tmpl", {
      installer_workspace = local.installer_workspace
      cluster_id          = var.cluster_id
      path_root            = path.cwd
    })
  }
}

  data "local_file" "bootstrap_ignition" {
  filename = "${local.installerdir}/bootstrap.ign"
  depends_on = [
    null_resource.generate_ignition
  ]
}


data "template_file" "append-bootstrap" {
  template = templatefile("${path.module}/templates/append-bootstrap.ign", {
    bootstrap_ignition_url = local.bootstrap_ignition_url
  })
    depends_on = [
      null_resource.generate_ignition
  ]
}

resource "local_file" "append-bootstrap" {
  content  = data.template_file.append-bootstrap.rendered
  filename = "${local.installerdir}/append-bootstrap.ign"
  depends_on = [
    null_resource.generate_manifests,
  ]
}
data "local_file" "master_ignition" {
  filename = "${local.installerdir}/master.ign"
  depends_on = [
    null_resource.generate_ignition
  ]
}


data "local_file" "worker_ignition" {
  filename = "${local.installerdir}/worker.ign"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "null_resource" "ignition_access_right" {
  depends_on = [  
    null_resource.generate_ignition, local_file.append-bootstrap
  ]
  provisioner "local-exec" {
    command = "chmod 644 ${local.installerdir}/bootstrap.ign"
  }
}