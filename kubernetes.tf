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
  # The Quortex cluster OIDC issuer.
  cluster_oidc_issuer = trimprefix(aws_eks_cluster.quortex.identity[0].oidc[0].issuer, "https://")
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

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.quortex-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.quortex-AmazonEKSServicePolicy,
  ]
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
      scaling_config.0.desired_size,
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
    var.tags
  )

  labels = merge(
    {
      "nodegroup" = each.key
    },
    lookup(each.value, "labels", {})
  )

  depends_on = [
    aws_iam_role_policy_attachment.quortex-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.quortex-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.quortex-AmazonEC2ContainerRegistryReadOnly,
  ]
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
  for_each = aws_eks_node_group.quortex

  triggers = {
    node_group        = each.value["resources"][0]["autoscaling_groups"][0]["name"]
    node_group_labels = jsonencode(lookup(var.node_groups[each.key], "labels", {}))
    tags              = jsonencode(var.tags)
  }

  provisioner "local-exec" {
    command = <<EOF
aws autoscaling create-or-update-tags \
--region ${data.aws_region.current.name} \
--tags \
"ResourceId=${each.value["resources"][0]["autoscaling_groups"][0]["name"]},ResourceType=auto-scaling-group,Key=nodegroup,Value=${each.key},PropagateAtLaunch=true" \
"ResourceId=${each.value["resources"][0]["autoscaling_groups"][0]["name"]},ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/node-template/label/nodegroup,Value=${each.key},PropagateAtLaunch=true" \
%{for k, v in lookup(var.node_groups[each.key], "labels", {})~}
"ResourceId=${each.value["resources"][0]["autoscaling_groups"][0]["name"]},ResourceType=auto-scaling-group,Key=${k},Value=${v},PropagateAtLaunch=true" \
"ResourceId=${each.value["resources"][0]["autoscaling_groups"][0]["name"]},ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/node-template/label/${k},Value=${v},PropagateAtLaunch=true" \
%{endfor~}
%{for k, v in var.tags~}
"ResourceId=${each.value["resources"][0]["autoscaling_groups"][0]["name"]},ResourceType=auto-scaling-group,Key=${k},Value=${v},PropagateAtLaunch=true" \
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
