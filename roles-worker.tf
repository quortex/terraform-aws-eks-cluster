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

# IAM Role to allow the worker nodes to manage or retrieve data from other AWS services. It is used by Kubernetes to allow worker nodes to join the cluster.

resource "aws_iam_role" "quortex_role_worker" {
  count       = var.handle_iam_resources ? 1 : 0
  name        = var.worker_role_name
  description = "IAM Role to allow the worker nodes to manage or retrieve data from other AWS services. It is used by Kubernetes to allow worker nodes to join the cluster."
  tags        = var.tags

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


# IAM role policies

resource "aws_iam_role_policy_attachment" "quortex_amazon_eks_worker_node_policy" {
  count      = var.handle_iam_resources ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.quortex_role_worker[0].name
}

resource "aws_iam_role_policy_attachment" "quortex_amazon_eks_cni_policy" {
  count      = var.handle_iam_resources ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.quortex_role_worker[0].name
}

resource "aws_iam_role_policy_attachment" "quortex_amazon_ec2_container_registry_readonly" {
  count      = var.handle_iam_resources ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.quortex_role_worker[0].name
}
