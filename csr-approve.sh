oc get csr --no-headers | awk '{print $1}' | xargs oc adm certificate approve
