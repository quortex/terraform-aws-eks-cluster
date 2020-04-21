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

  tags = {
    Name = var.name
  }
}

resource "aws_security_group_rule" "quortex-ingress-workstation-https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.quortex.id
  to_port           = 443
  type              = "ingress"

  cidr_blocks = [for name, cidr in var.master_authorized_networks: cidr]
  # TODO: should we specify 1 rule per cidr block, 
  # or a single rule with multiple cidr blocks, like this ?
}

# Cluster

resource "aws_eks_cluster" "quortex" {
  name     = var.name
  role_arn = aws_iam_role.quortex_role_master.arn

  vpc_config {
    security_group_ids = [aws_security_group.quortex.id]
    subnet_ids         = var.subnet_ids
  }

  tags = var.resource_labels # TODO: are these labels intended for AWS resource tagging, or Kubernetes node labelling ?

  depends_on = [
    aws_iam_role_policy_attachment.quortex-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.quortex-AmazonEKSServicePolicy,
  ]
}


# Worker nodes

resource "aws_eks_node_group" "quortex" {
  cluster_name    = aws_eks_cluster.quortex.name
  node_group_name = "${var.name}_workers"
  node_role_arn   = aws_iam_role.quortex_role_worker.arn
  subnet_ids         = var.subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  tags = var.resource_labels

  depends_on = [
    aws_iam_role_policy_attachment.quortex-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.quortex-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.quortex-AmazonEC2ContainerRegistryReadOnly,
  ]
}

