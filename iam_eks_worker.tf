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

# EKS Managed worker nodes IAM
#
# IAM Role to allow the worker nodes to manage or retrieve data from other AWS
# services. It is used by Kubernetes to allow worker nodes to join the cluster.

locals {
  handle_quortex_role_worker_iam = var.handle_iam_resources && length(var.node_groups) > 0
}

resource "aws_iam_role" "quortex_role_worker" {
  count       = local.handle_quortex_role_worker_iam ? 1 : 0
  name        = var.worker_role_name
  description = "IAM Role to allow the EKS managed worker nodes to manage or retrieve data from other AWS services. It is used by Kubernetes to allow worker nodes to join the cluster."
  tags        = var.tags

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Principal = {
            Service = "ec2.amazonaws.com"
          },
          Action = "sts:AssumeRole"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "quortex_amazon_eks_worker_node_policy" {
  count      = local.handle_quortex_role_worker_iam ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.quortex_role_worker[0].name
}

resource "aws_iam_role_policy_attachment" "quortex_amazon_ec2_container_registry_readonly" {
  count      = local.handle_quortex_role_worker_iam ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.quortex_role_worker[0].name
}

# Self managed worker nodes IAM
#
# IAM Role to allow the worker nodes to manage or retrieve data from other AWS
# services. It is used by Kubernetes to allow worker nodes to join the cluster.

locals {
  handle_quortex_role_self_managed_worker_iam = var.handle_iam_resources && length(var.node_groups_advanced) > 0
}

resource "aws_iam_role" "quortex_role_self_managed_worker" {
  count       = local.handle_quortex_role_self_managed_worker_iam ? 1 : 0
  name        = var.self_managed_worker_role_name
  description = "IAM Role to allow the self managed worker nodes to manage or retrieve data from other AWS services. It is used by Kubernetes to allow worker nodes to join the cluster."
  tags        = var.tags

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Principal = {
            Service = "ec2.amazonaws.com"
          },
          Action = "sts:AssumeRole"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "quortex_self_managed_amazon_eks_worker_node_policy" {
  count      = local.handle_quortex_role_self_managed_worker_iam ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.quortex_role_self_managed_worker[0].name
}

resource "aws_iam_role_policy_attachment" "quortex_self_managed_amazon_ec2_container_registry_readonly" {
  count      = local.handle_quortex_role_self_managed_worker_iam ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.quortex_role_self_managed_worker[0].name
}
