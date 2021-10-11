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
fips: ${var.fips}
pullSecret: '${chomp(file(var.pull_secret))}'
sshKey: '${var.ssh_public_key}'
%{if var.additionalTrustBundle != ""}
${indent(2, "additionalTrustBundle: |\n${file(var.additionalTrustBundle)}")}
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
csr_common_secret    = base64encode(file("${path.module}/templates/common.sh"))
csr_approve_secret   = base64encode(file("${path.module}/templates/approve-csrs.sh"))
user_cmds_secret     = base64encode(file("${path.module}/templates/post-install-user-cmds.sh"))
chrony_secret        = base64encode(file("${path.module}/templates/chrony.yaml"))
label_storage_nodes_secret  = base64encode(<<EOF
# find out if OCP is up
ready_storage_nodes_count=0
while [ $ready_storage_nodes_count -lt ${var.storage_count} ]; do
   ready_storage_nodes_count=$(oc get nodes | awk '{print $1, $2}' | grep storage- | grep Ready | wc -l)
   echo "Ready storage nodes count: " $ready_storage_nodes_count
   sleep 10
done
oc patch OperatorHub cluster --type json  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
%{ for hostname in var.storage_fqdns ~}
oc label node  ${hostname} node-role.kubernetes.io/infra=""
oc label node  ${hostname}  cluster.ocs.openshift.io/openshift-storage=""
oc adm taint node ${hostname} node.ocs.openshift.io/storage="true":NoSchedule
%{ endfor ~}
EOF
)

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


data "template_file" "post_deployment_07_secret" {
  template = <<EOF
apiVersion: v1
kind: Secret
data:
  post-deployment-user-cmds.sh: ${local.user_cmds_secret}
metadata:
  name: user-cmds-scripts
  namespace: ibm-post-deployment
type: Opaque
EOF
}

resource "local_file" "post_deployment_07" {
  content  = data.template_file.post_deployment_07_secret.rendered
  filename = "${local.installerdir}/manifests/99_07-post-deployment.yaml"
  depends_on = [
    null_resource.generate_manifests,
  ]
}


data "template_file" "post_deployment_08" {
  template = <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: user-cmds
  namespace: ibm-post-deployment
spec:
  containers:
  - name: user-cmds
    imagePullPolicy: Always
    %{if var.airgapped["enabled"]}
    image: ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/openshift/origin-cli:latest
    %{else}
    image: quay.io/openshift/origin-cli:latest
    %{endif}
    command: ["/bin/sh", "-c"]
    args:
      - "mkdir /tmp/user-cmds-rw && cp /tmp/user-cmds/*.sh /tmp/user-cmds-rw && cd /tmp/user-cmds-rw && ./post-install-user-cmds.sh "
    volumeMounts:
      - name: user-cmds
        mountPath: /tmp/user-cmds
  restartPolicy: Never
  serviceAccount: ibm-deployment-sa
  volumes:
    - name: user-cmds
      secret:
        defaultMode: 0755
        secretName: user-cmds-scripts
  tolerations:
    - operator: Exists
  nodeSelector:
    node-role.kubernetes.io/master: ''
EOF
}

// change filename to yaml from bkup to enable this function
resource "local_file" "post_deployment_08" {
  content  = data.template_file.post_deployment_08.rendered
  filename = "${local.installerdir}/manifests/99_08-post-deployment.bkup"
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

data "template_file" "cluster_scheduler" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  %{if var.compute_count == 0}
  mastersSchedulable: true
  %{else}
  mastersSchedulable: false
    %{endif}  
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

data "template_file" "chrony_master_config" {
  count    = var.airgapped["enabled"] ? 1 : 0
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: masters-chrony-configuration
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 3.1.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${local.chrony_secret}
        mode: 420
        overwrite: true
        path: /etc/chrony.conf
  osImageURL: ""
EOF
}

resource "local_file" "chrony_master_config" {
  count    = var.airgapped["enabled"] ? 1 : 0
  content  = element(data.template_file.chrony_master_config.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_masters_chrony_config.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "chrony_worker_config" {
  count    = var.airgapped["enabled"] ? 1 : 0
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: workers-chrony-configuration
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 3.1.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${local.chrony_secret}
        mode: 420
        overwrite: true
        path: /etc/chrony.conf
  osImageURL: ""
EOF
}

resource "local_file" "chrony_worker_config" {
  count    = var.airgapped["enabled"] ? 1 : 0
  content  = element(data.template_file.chrony_worker_config.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_worker_chrony_config.yaml"
  depends_on = [
    null_resource.download_binaries,
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

data "template_file" "label_storage_nodes" {
count = var.storage_count > 3 ? 1 : 0
  template = <<EOF
apiVersion: v1
kind: Secret
data:
  label_storage_nodes.sh: ${local.label_storage_nodes_secret}
metadata:
  name: label-storage-nodes
  namespace: ibm-post-deployment
type: Opaque
---
apiVersion: v1
kind: Pod
metadata:
  name: label-storage-nodes
  namespace: ibm-post-deployment
spec:
  containers:
  - name: label-storage-nodes
    imagePullPolicy: Always
    %{if var.airgapped["enabled"]}
    image: ${var.airgapped["mirror_fqdn"]}:${var.airgapped["mirror_port"]}/openshift/origin-cli:latest
    %{else}
    image: quay.io/openshift/origin-cli:latest
    %{endif}
    command: ["/bin/sh", "-c"]
    args:
      - "mkdir /tmp/label-nodes-rw && cp /tmp/label-nodes/*.sh /tmp/label-nodes-rw && cd /tmp/label-nodes-rw && ./label_storage_nodes.sh "
    volumeMounts:
      - name: label-nodes
        mountPath: /tmp/label-nodes
  restartPolicy: Never
  serviceAccount: ibm-deployment-sa
  volumes:
    - name: label-nodes
      secret:
        defaultMode: 0755
        secretName: label-storage-nodes
  tolerations:
    - operator: Exists
  nodeSelector:
    node-role.kubernetes.io/master: ''
EOF
}

resource "local_file" "label_storage_nodes" {
  count = var.storage_count > 3 ? 1 : 0
  content  = data.template_file.label_storage_nodes[count.index].rendered
  filename = "${local.installerdir}/manifests/99_label_storage_nodes.yaml"
  depends_on = [
    null_resource.generate_manifests,
  ]
}
