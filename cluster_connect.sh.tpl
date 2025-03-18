%{ if use_max_pods == false }
# Calculate max pods
KUBELET_CONFIG=/etc/kubernetes/kubelet/kubelet-config.json
set +o pipefail
CNI_VERSION=$(echo "${cni_version}" | sed 's/^v//')
MAX_PODS=$(/etc/eks/max-pods-calculator.sh --instance-type-from-imds \
--cni-version $CNI_VERSION \
%{ if show_max_allowed } --show-max-allowed%{ endif } \
--cni-custom-networking-enabled)
set -o pipefail
if [[ -n "$MAX_PODS" ]]; then
  echo "$(jq ".maxPods=$MAX_PODS" $KUBELET_CONFIG)" > $KUBELET_CONFIG
else
  echo "Not able to determine maxPods for instance. Not setting max pods for kubelet"
fi
%{ endif }

/etc/eks/bootstrap.sh ${cluster_name} \
  --use-max-pods ${use_max_pods} \
  --kubelet-extra-args '--node-labels=${node_labels} --register-with-taints=${node_taints} ${kubelet_extra_args}' \
  --b64-cluster-ca ${base64_cluster_ca} \
  --apiserver-endpoint ${api_server_url}

%{ if discard_unpacked_layers == false }
# Retain unpacked layers. We avoid using the configuration merge capability of containerd due to a known bug.
# For more details, refer to: https://github.com/containerd/containerd/issues/5837
sed -i '/discard_unpacked_layers = true/s/true/false/' /etc/containerd/config.toml
systemctl restart containerd
%{ endif }
