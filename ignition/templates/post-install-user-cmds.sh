# find out if OCP is up

machine_configpool_updated=0
while [ $machine_configpool_updated -lt 2 ]; do
   machine_configpool_updated=$(oc get machineconfigpool |  awk '{print $3}' | grep True |wc -l)
   echo "machine config count: " $machine_configpool_updated
   sleep 10
done   
oc patch OperatorHub cluster --type json  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
oc annotate namespace openshift-storage openshift.io/node-selector=
oc label node  storage-00.testinf.cdastu.com storage-01.testinf.cdastu.com storage-02.testinf.cdastu.com node-role.kubernetes.io/infra=""
oc label node storage-00.testinf.cdastu.com storage-01.testinf.cdastu.com storage-02.testinf.cdastu.com cluster.ocs.openshift.io/openshift-storage=""
oc adm taint node storage-00.testinf.cdastu.com storage-01.testinf.cdastu.com storage-02.testinf.cdastu.com node.ocs.openshift.io/storage="true":NoSchedule