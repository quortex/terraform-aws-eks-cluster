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


# IAM Role to allow EKS service to manage other AWS services

resource "aws_iam_role" "quortex_role_master" {
  count       = var.handle_iam_resources ? 1 : 0
  name        = var.master_role_name
  description = "IAM Role to allow EKS service to manage other AWS services"
  tags        = var.tags

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "quortex-AmazonEKSClusterPolicy" {
  count      = var.handle_iam_resources ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.quortex_role_master[0].name
}

resource "aws_iam_role_policy_attachment" "quortex-AmazonEKSServicePolicy" {
  count      = var.handle_iam_resources ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.quortex_role_master[0].name
}
