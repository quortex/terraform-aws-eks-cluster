Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash
set -ex
if TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
&& curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/autoscaling/target-lifecycle-state | grep "InService"; then
    /etc/eks/bootstrap.sh ${cluster_name} \
        --use-max-pods ${use_max_pods} \
        --kubelet-extra-args '--node-labels=${node_labels} --register-with-taints=${node_taints} ${kubelet_extra_args}' \
        --b64-cluster-ca ${base64_cluster_ca} \
        --apiserver-endpoint ${api_server_url}
fi
--//--