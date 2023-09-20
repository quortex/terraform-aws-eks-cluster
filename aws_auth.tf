# This file contains the configuration needed to link AWS IAM principals with
# the permissions granted to them on the Kubernetes APIs.
#
# It is largely inspired by the official terraform-aws-eks module
# (https://github.com/terraform-aws-modules/terraform-aws-eks/blob/918aa7cc40cbc072836410747834de64d84f514d/main.tf#L465).
#
# To configure permissions according to your needs, please consult the official
# documentation
# (https://github.com/kubernetes-sigs/aws-iam-authenticator#full-configuration-format).

locals {
  # Formats data to be written to aws-auth configmap.
  aws_auth_configmap_data = {
    mapRoles = replace(yamlencode(concat(
      [for r in concat(aws_iam_role.quortex_role_worker, aws_iam_role.quortex_role_self_managed_worker) : {
        rolearn  = r.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }],
      var.aws_auth_roles
    )), "\"", "")
    mapUsers    = replace(yamlencode(var.aws_auth_users), "\"", "")
    mapAccounts = replace(yamlencode(var.aws_auth_accounts), "\"", "")
  }
}

resource "kubernetes_config_map" "aws_auth" {
  count = var.create_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  lifecycle {
    # We are ignoring the data here since we will manage it with the resource below
    # This is only intended to be used in scenarios where the configmap does not exist
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.manage_aws_auth_configmap ? 1 : 0

  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  depends_on = [
    # Required for instances where the configmap does not exist yet to avoid race condition
    kubernetes_config_map.aws_auth,
  ]
}
