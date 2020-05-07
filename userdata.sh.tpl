#!/bin/bash 
set -ex 
/etc/eks/bootstrap.sh ${cluster_name} --kubelet-extra-args '--node-labels=eks.amazonaws.com/nodegroup-image=${ami_id},eks.amazonaws.com/nodegroup=${nodegroup_name} ${kubelet_more_extra_args}' --b64-cluster-ca ${base64_cluster_ca} --apiserver-endpoint ${api_server_url}
