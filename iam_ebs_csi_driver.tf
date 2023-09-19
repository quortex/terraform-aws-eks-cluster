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
  handle_iam_ebs_csi_driver = var.handle_iam_resources && (var.handle_iam_ebs_csi_driver || contains(keys(var.cluster_addons), "aws-ebs-csi-driver"))
}

resource "aws_iam_role" "ebs_csi_driver" {
  count       = local.handle_iam_ebs_csi_driver ? 1 : 0
  name        = var.ebs_csi_driver_role_name
  description = "IAM Role required for Amazon EBS CSI driver."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.cluster_oidc_issuer}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.cluster_oidc_issuer}:aud" : "sts.amazonaws.com"
            "${local.cluster_oidc_issuer}:sub" : "system:serviceaccount:${var.ebs_csi_driver_sa.namespace}:${var.ebs_csi_driver_sa.name}"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "ebs_csi_driver" {
  count       = local.handle_iam_ebs_csi_driver ? 1 : 0
  description = "The policy required for Amazon EBS CSI driver."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:DetachVolume",
          "ec2:ModifyVolume"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = local.handle_iam_ebs_csi_driver ? 1 : 0
  policy_arn = aws_iam_policy.ebs_csi_driver[0].arn
  role       = aws_iam_role.ebs_csi_driver[0].name
}
