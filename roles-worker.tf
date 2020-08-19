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

### Attach a new policy for the cluster-autoscaler to the worker role

resource "aws_iam_policy" "quortex-autoscaler-policy" {
  description = "Allow the cluster autoscaler to make calls to the AWS APIs."

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "quortex-autoscaler-policy-attach" {
  role       = aws_iam_role.quortex_role_worker.name
  policy_arn = aws_iam_policy.quortex-autoscaler-policy.arn
}

### Attach a new policy for the cloudwatch-exporter to the worker role

resource "aws_iam_policy" "quortex-cloudwatch-policy" {
  count = var.add_cloudwatch_permissions ? 1 : 0

  description = "Allow the cloudwatch-exporter to make calls to the AWS CloudWatch APIs."

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:GetMetricData",
                "tag:GetResources"
            ],
            "Resource": "*", 
            "Effect": "Allow"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "quortex-cloudwatch-policy-attach" {
  count = var.add_cloudwatch_permissions ? 1 : 0

  role       = aws_iam_role.quortex_role_worker.name
  policy_arn = aws_iam_policy.quortex-cloudwatch-policy[0].arn
}
