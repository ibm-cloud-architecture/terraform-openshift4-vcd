data "template_file" "install_config_yaml" {
  template = <<EOF
apiVersion: v1
baseDomain: ${var.base_domain}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ${var.cluster_id}
networking:
  clusterNetwork:
  - cidr: ${var.cluster_cidr}
    hostPrefix: ${var.cluster_hostprefix}
  networkType: OpenShiftSDN
  serviceNetwork:
  - ${var.cluster_servicecidr}
platform:
  none: {}  
pullSecret: '${chomp(file(var.pull_secret))}'
sshKey: '${var.ssh_public_key}'
%{if var.airgapped["additionalTrustBundle"] != ""}
${indent(2, "additionalTrustBundle: |\n${file(var.airgapped["additionalTrustBundle"])}")}
%{endif}
%{if var.airgapped["enabled"]}imageContentSources:
- mirrors:
  - ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/${var.airgapped["mirror_repository"]}
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/${var.airgapped["mirror_repository"]}
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
%{endif}
%{if var.proxy_config["enabled"]}proxy:
  httpProxy: ${var.proxy_config["httpProxy"]}
  httpsProxy: ${var.proxy_config["httpsProxy"]}
  noProxy: ${var.proxy_config["noProxy"]}
%{endif}
EOF
}

locals {
installer_workspace = "${path.cwd}/installer/${var.cluster_id}"
node_count = var.total_node_count
csr_common_secret  = base64encode(file("${path.module}/templates/common.sh"))
csr_approve_secret = base64encode(file("${path.module}/templates/approve-csrs.sh"))

}
resource "local_file" "install_config_yaml" {
  content  = data.template_file.install_config_yaml.rendered
  filename = "${path.cwd}/installer/${var.cluster_id}/install-config.yaml"
  depends_on = [
    null_resource.download_binaries,
  ]
}

data "template_file" "post_deployment_05" {
  template = <<EOF
apiVersion: v1
kind: Secret
data:
  common.sh: ${local.csr_common_secret}
  approve-csrs.sh: ${local.csr_approve_secret}
metadata:
  name: approve-csrs-scripts
  namespace: ibm-post-deployment
type: Opaque
EOF
}

resource "local_file" "post_deployment_05" {
  content  = data.template_file.post_deployment_05.rendered
  filename = "${local.installerdir}/manifests/99_05-post-deployment.yaml"
  depends_on = [
    null_resource.generate_manifests,
  ]
}

data "template_file" "post_deployment_06" {
  template = <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: approve-csrs
  namespace: ibm-post-deployment
spec:
  containers:
  - name: csr-approve
    imagePullPolicy: Always
    %{if var.airgapped["enabled"]}    
    image: ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/openshift/origin-cli:latest
    %{else}    
    image: quay.io/openshift/origin-cli:latest
    %{endif}
    command: ["/bin/sh", "-c"]
    args: 
      - "mkdir /tmp/csrs-rw && cp /tmp/csrs/*.sh /tmp/csrs-rw && cd /tmp/csrs-rw && ./approve-csrs.sh --wait-count 60 --nodes ${local.node_count}"
    volumeMounts:
      - name: approve-csrs
        mountPath: /tmp/csrs
  restartPolicy: Never
  serviceAccount: ibm-deployment-sa
  volumes:
    - name: approve-csrs
      secret:
        defaultMode: 0755
        secretName: approve-csrs-scripts
  tolerations:
    - operator: Exists
  nodeSelector:
    node-role.kubernetes.io/master: ''
EOF
}

resource "local_file" "post_deployment_06" {
  content  = data.template_file.post_deployment_06.rendered
  filename = "${local.installerdir}/manifests/99_06-post-deployment.yaml"
  depends_on = [
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-dns-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: DNS
metadata:
  creationTimestamp: null
  name: cluster
spec:
  baseDomain: ${var.cluster_id}.${var.base_domain}
  privateZone:
    id: /subscriptions/resourceGroups/providers/Microsoft.Network/privateDnsZones/${var.cluster_id}.${var.base_domain}
  publicZone:
    id: /subscriptions/resourceGroups/providers/Microsoft.Network/dnszones/${var.base_domain}
status: {}
EOF
}

resource "local_file" "cluster-dns-02-config" {
  content  = data.template_file.cluster-dns-02-config.rendered
//  filename = "${local.installer_workspace}/manifests/cluster-dns-02-config.yml"
  filename = "${local.installer_workspace}/cluster-dns-02-config.bkp"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}



//data "template_file" "configure-image-registry-job" {
//  template = <<EOF
//apiVersion: batch/v1
//kind: Job
//metadata:
//  name: ibm-configure-image-registry
//  namespace: openshift-image-registry
//spec:
//  parallelism: 1
//  completions: 1
//  template:
//    metadata:
//      name: configure-image-registry
//      labels:
//        app: configure-image-registry
//    serviceAccountName: infra
//    spec:
//      containers:
//      - name:  client
//        image: quay.io/openshift/origin-cli:latest
//        command: ["/bin/sh","-c"]
//        args: ["while ! /usr/bin/oc get configs.imageregistry.operator.openshift.io cluster >/dev/null 2>&1; do sleep 1;done;/usr/bin/oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{\"spec\": {\"nodeSelector\": {\"node-role.kubernetes.io/infra\": \"\"}}}'"]
//      restartPolicy: Never
//EOF
//}

//resource "local_file" "configure-image-registry-job" {
//  content  = data.template_file.configure-image-registry-job.rendered
//  filename = "${local.installer_workspace}/openshift/99_configure-image-registry-job.yml"
//  depends_on = [
//    null_resource.download_binaries,
//    null_resource.generate_manifests,
//  ]
//}

data "template_file" "cluster_scheduler" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  mastersSchedulable: false
  policy:
    name: ""
status: {}
EOF
}
 resource "local_file" "cluster_scheduler" {
  content  = data.template_file.cluster_scheduler.rendered
  filename = "${local.installerdir}/manifests/cluster-scheduler-02-config.yml"
  depends_on = [
    null_resource.generate_manifests,
  ]
}

data "template_file" "airgapped_registry_upgrades" {
  count    = var.airgapped["enabled"] ? 1 : 0
  template = <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: airgapped
spec:
  repositoryDigestMirrors:
  - mirrors:
    - ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/${var.airgapped["mirror_repository"]}
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/${var.airgapped["mirror_repository"]}
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF
}

resource "local_file" "airgapped_registry_upgrades" {
  count    = var.airgapped["enabled"] ? 1 : 0
  content  = element(data.template_file.airgapped_registry_upgrades.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_airgapped_registry_upgrades.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}