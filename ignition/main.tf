

//data "template_file" "post_deployment_05" {
//  template = templatefile("${path.module}/templates/99_05-post-deployment.yaml", {
//    csr_common_secret  = base64encode(file("${path.module}/templates/common.sh"))
//    csr_approve_secret = base64encode(file("${path.module}/templates/approve-csrs.sh"))
//  })
//}

//data "template_file" "post_deployment_06" {
//  template = templatefile("${path.module}/templates/99_06-post-deployment.yaml", {
//    node_count = var.total_node_count
//  })
//}

locals {
  installerdir = "${path.cwd}/installer/${var.cluster_id}"
  openshift_installer_url = "${var.openshift_installer_url}/latest-${var.openshift_version}"
  bootstrap_ignition_url = "http://172.16.0.10${local.installerdir}/bootstrap.ign"
  mirror_fqdn = var.airgapped["mirror_fqdn"]
  mirror_port = var.airgapped["mirror_port"]
  mirror_repository = var.airgapped["mirror_repository"]
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
      openshift_version    = var.openshift_version
      path_root            = path.cwd
    })
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ./installer-files"
  }

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


//resource "null_resource" "generate_manifests" {
//  provisioner "local-exec" {
//    command = <<EOF
//set -ex
//${local.installerdir}/openshift-install --dir=${local.installerdir}/ create manifests --log-level debug
//touch ${local.installerdir}/openshift/99_openshift-cluster-api_master-machines1
//rm ${local.installerdir}/openshift/99_openshift-cluster-api_master-machines*
//touch ${local.installerdir}/openshift/99_openshift-cluster-api_worker-machineset1
//rm ${local.installerdir}/openshift/99_openshift-cluster-api_worker-machineset*
//cp ${path.module}/templates/99_01-post-deployment.yaml ${local.installerdir}/manifests
//cp ${path.module}/templates/99_02-post-deployment.yaml ${local.installerdir}/manifests
//cp ${path.module}/templates/99_03-post-deployment.yaml ${local.installerdir}/manifests
//cp ${path.module}/templates/99_04-post-deployment.yaml ${local.installerdir}/manifests
//EOF
//  }
//  depends_on = [
//    local_file.install_config_yaml
//  ]
//}


//resource "local_file" "post_deployment_05" {
//  content  = data.template_file.post_deployment_05.rendered
//  filename = "${local.installerdir}/manifests/99_05-post-deployment.yaml"
//  depends_on = [
//    null_resource.generate_manifests,
//  ]
//}





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

