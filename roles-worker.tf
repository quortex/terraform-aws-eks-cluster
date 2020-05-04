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
  name        = var.worker_role_name
  description = "IAM Role to allow the worker nodes to manage or retrieve data from other AWS services. It is used by Kubernetes to allow worker nodes to join the cluster."

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

  # tags = map(
  #   "Name", "${var.worker_role_name}",
  # )
}


# IAM role policies

resource "aws_iam_role_policy_attachment" "quortex-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.quortex_role_worker.name
}

resource "aws_iam_role_policy_attachment" "quortex-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.quortex_role_worker.name
}

resource "aws_iam_role_policy_attachment" "quortex-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.quortex_role_worker.name
}

