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

# Security group

resource "aws_security_group" "quortex" {
  name        = var.name
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = var.name
    },
    var.tags
  )
}
# TODO: should the security group be defined in the cluster module or in the network module ?


resource "aws_security_group_rule" "quortex_ingress_authorized" {
  for_each = var.master_authorized_networks

  description       = each.key
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.quortex.id
  to_port           = 443
  type              = "ingress"

  cidr_blocks = [each.value]
}

# Cluster

resource "aws_eks_cluster" "quortex" {
  name     = var.name
  role_arn = aws_iam_role.quortex_role_master.arn
  version  = var.kubernetes_version

  vpc_config {
    security_group_ids = [aws_security_group.quortex.id]
    subnet_ids         = var.subnet_ids_master
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.quortex-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.quortex-AmazonEKSServicePolicy,
  ]
}

# Worker nodes

resource "aws_eks_node_group" "quortex" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.quortex.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.quortex_role_worker.arn
  subnet_ids      = var.subnet_ids_worker

  scaling_config {
    desired_size = lookup(each.value, "scaling_desired_size", 1)
    min_size     = lookup(each.value, "scaling_min_size", 1)
    max_size     = lookup(each.value, "scaling_max_size", 1)
  }

  instance_types = lookup(each.value, "instance_types", ["t3.medium"])
  disk_size      = lookup(each.value, "disk_size", 20)

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.quortex-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.quortex-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.quortex-AmazonEC2ContainerRegistryReadOnly,
  ]
}

