/etc/eks/bootstrap.sh ${cluster_name} \
  --use-max-pods ${use_max_pods} \
  --kubelet-extra-args '--node-labels=${node_labels} --register-with-taints=${node_taints} ${kubelet_extra_args}' \
  --b64-cluster-ca ${base64_cluster_ca} \
  --apiserver-endpoint ${api_server_url}
