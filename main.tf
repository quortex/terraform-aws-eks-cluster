/**
 * Copyright 2020 Quortex
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

locals {
  vpc_cni_configuration_values = var.handle_eni_configs ? {
    "eniConfig" : {
      "create" : true,
      "region" : data.aws_region.current.name,
      "subnets" : { for e in var.pods_subnets :
        e.availability_zone => {
          id             = e.id
          securityGroups = [aws_eks_cluster.quortex.vpc_config[0].cluster_security_group_id]
        }
      }
    }
  } : null
  # The Quortex cluster OIDC issuer.
  cluster_oidc_issuer = trimprefix(aws_eks_cluster.quortex.identity[0].oidc[0].issuer, "https://")
  node_group_labels = [
    for key, node_group in var.node_groups :
    {
      for k, v in lookup(node_group, "labels", {}) :
      key => {
        "k8s.io/cluster-autoscaler/node-template/label/${k}" : v
        (k) : v
      }...
    }
  ]
  node_groups_tags = {
    for key, node_group in var.node_groups :
    key => {
      for k, v in lookup(node_group, "tags", {}) :
      k => v
    }
  }
  asg_custom_tags_chunks = chunklist(flatten([
    for key, node_group in var.node_groups : [
      for k, v in merge({
        nodegroup : key,
        "k8s.io/cluster-autoscaler/node-template/label/nodegroup" : key
        },
        merge(local.node_group_labels[0][key]...),
        merge(local.node_groups_tags[key]),
        var.tags,
        var.compute_tags
      ) :
      {
        node_group : key,
        key : k,
        tag : v
      }
    ]
  ]), 5)
}

# This data source is used to get the access to the effective Account ID, User ID, and ARN in which Terraform is authorized.
data "aws_caller_identity" "current" {}

# This datasource is used to get the region currently used by the AWS provider
data "aws_region" "current" {}

# Cluster
resource "aws_eks_cluster" "quortex" {
  name     = var.cluster_name
  role_arn = var.handle_iam_resources ? aws_iam_role.quortex_role_master[0].arn : var.master_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.master_subnet_ids

    # Public endpoint: enabled but restricted to an IP range list
    endpoint_public_access = true
    public_access_cidrs    = [for label, cidr_block in var.master_authorized_networks : cidr_block]

    # Private endpoint: enabled for communication between worker nodes and the API server (since public endpoint is restricted)
    endpoint_private_access = true
    # Note: for private endpoint to work, DNS hostnames must be enabled in the VPC
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.quortex_amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.quortex_amazon_eks_service_policy,
    aws_cloudwatch_log_group.cluster_logs
  ]
}

resource "aws_security_group_rule" "cluster_security_group_additional" {
  for_each = var.cluster_security_group_additional_rules

  security_group_id        = aws_eks_cluster.quortex.vpc_config[0].cluster_security_group_id
  description              = each.value.description
  protocol                 = each.value.protocol
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  cidr_blocks              = each.value.cidr_blocks
  ipv6_cidr_blocks         = each.value.ipv6_cidr_blocks
  prefix_list_ids          = each.value.prefix_list_ids
  source_security_group_id = each.value.source_security_group_id
}

data "tls_certificate" "quortex_cluster" {
  url = aws_eks_cluster.quortex.identity[0].oidc[0].issuer
}

# Provides an IAM OpenID Connect provider for the cluster.
resource "aws_iam_openid_connect_provider" "quortex_cluster" {
  count           = var.handle_iam_resources ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.quortex_cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.quortex.identity[0].oidc[0].issuer

  tags = var.tags
}

# Worker nodes
resource "aws_eks_node_group" "quortex" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.quortex.name
  version         = var.kubernetes_worker_nodes_version
  node_group_name = lookup(each.value, "name", "${var.cluster_name}_${each.key}")
  node_role_arn   = var.handle_iam_resources ? aws_iam_role.quortex_role_worker[0].arn : var.worker_role_arn
  subnet_ids      = lookup(each.value, "subnet_ids", [])

  scaling_config {
    desired_size = lookup(each.value, "scaling_desired_size", lookup(each.value, "scaling_min_size", 1))
    min_size     = lookup(each.value, "scaling_min_size", 1)
    max_size     = lookup(each.value, "scaling_max_size", 1)
  }

  lifecycle {
    ignore_changes = [
      # ignore changes to the cluster size, because it can be changed by autoscaling
      scaling_config[0].desired_size,
    ]
  }

  instance_types = lookup(each.value, "instance_types", ["t3.medium"])
  disk_size      = lookup(each.value, "disk_size", 20)

  dynamic "remote_access" {
    for_each = var.remote_access_ssh_key != null ? [true] : []

    content {
      ec2_ssh_key               = var.remote_access_ssh_key
      source_security_group_ids = aws_security_group.remote_access[*].id
    }
  }

  tags = merge(
    lookup(each.value, "cluster_autoscaler_enabled", true) ? {
      # tag the node group so that it can be auto-discovered by the cluster autoscaler
      "k8s.io/cluster-autoscaler/${var.cluster_name}"           = "owned",
      "k8s.io/cluster-autoscaler/enabled"                       = lookup(each.value, "cluster_autoscaler_enabled", true),
      "k8s.io/cluster-autoscaler/node-template/label/nodegroup" = each.key, # tag required for scaling to/from 0
    } : {},
    { "nodegroup" = each.key },
    lookup(each.value, "labels", {}),
    lookup(each.value, "tags", {}),
    var.tags
  )

  labels = merge(
    {
      "nodegroup" = each.key
    },
    lookup(each.value, "labels", {})
  )

  depends_on = [
    aws_iam_role_policy_attachment.quortex_amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.quortex_amazon_ec2_container_registry_readonly,
    kubernetes_config_map_v1_data.aws_auth
  ]
}

locals {
  addon_irsa_service_account_arn = {
    vpc-cni            = try(aws_iam_role.aws_vpc_cni[0].arn, null)
    aws-ebs-csi-driver = try(aws_iam_role.ebs_csi_driver[0].arn, null)
  }
}

resource "aws_eks_addon" "vpc_cni_addon" {
  count = var.vpc_cni_addon != null ? 1 : 0

  cluster_name                = aws_eks_cluster.quortex.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_addon.version
  configuration_values        = jsonencode(merge(local.vpc_cni_configuration_values, var.vpc_cni_addon.configuration_values))
  preserve                    = var.vpc_cni_addon.preserve
  resolve_conflicts_on_update = var.vpc_cni_addon.resolve_conflicts
  resolve_conflicts_on_create = var.vpc_cni_addon.resolve_conflicts
  service_account_role_arn    = lookup(local.addon_irsa_service_account_arn, "vpc-cni", null)

  tags = var.tags
}

# Eks addons
resource "aws_eks_addon" "quortex_addon" {
  for_each = { for k, v in var.cluster_addons : k => v if k != "vpc-cni" }

  cluster_name                = aws_eks_cluster.quortex.name
  addon_name                  = each.key
  addon_version               = each.value.version
  configuration_values        = try(each.value.configuration_values, null)
  preserve                    = try(each.value.preserve, null)
  resolve_conflicts_on_update = try(each.value.resolve_conflicts, "OVERWRITE")
  resolve_conflicts_on_create = try(each.value.resolve_conflicts, "OVERWRITE")
  service_account_role_arn    = lookup(local.addon_irsa_service_account_arn, each.key, null)

  tags = var.tags
}

# This AWS CLI command will add tags to the ASG created by EKS
#
# The tags specified on the resource type "aws_eks_node_group" are not propagated to the ASG that
# represents this node group (issue https://github.com/aws/containers-roadmap/issues/608).
#
# As a workaround, we add tags to the ASG after the nodegroup creation/updates using the AWS
# command-line.
#
# Thanks to the PropagateAtLaunch=true argument, these tags will also be propagated to instances
# created in this ASG.
#
# Note: existing tags on the ASGs will not be removed
resource "null_resource" "add_custom_tags_to_asg" {
  count = length(local.asg_custom_tags_chunks)

  triggers = {
    asg_custom_tags_chunk = jsonencode(local.asg_custom_tags_chunks[count.index])
  }

  provisioner "local-exec" {
    command = <<EOF
aws autoscaling create-or-update-tags \
--region ${data.aws_region.current.name} \
--tags \
%{for v in local.asg_custom_tags_chunks[count.index]~}
"ResourceId=${aws_eks_node_group.quortex[v.node_group]["resources"][0]["autoscaling_groups"][0]["name"]},ResourceType=auto-scaling-group,Key='${v.key}',Value='${v.tag}',PropagateAtLaunch=true" \
%{endfor~}

EOF
  }
}

resource "aws_security_group" "remote_access" {
  # Create this security group only if remote access is requested
  count = var.remote_access_ssh_key != null ? 1 : 0

  name        = "${var.cluster_name}-ssh"
  description = "Allow remote access (SSH)"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH access from specified IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.remote_access_allowed_ip_ranges
  }

  tags = merge(
    {
      "Name" = "${var.cluster_name}-ssh"
    },
    var.tags
  )
}

resource "aws_cloudwatch_log_group" "cluster_logs" {
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_logs_retention
  tags              = var.tags
}
