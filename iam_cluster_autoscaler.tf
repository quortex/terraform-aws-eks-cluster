resource "aws_iam_role" "quortex_role_autoscaler" {
  count       = var.handle_iam_resources ? 1 : 0
  name        = var.autoscaler_role_name
  description = "IAM Role to allow the autoscaler service account to manage AWS Autoscaling."
  tags        = var.tags

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
            "${local.cluster_oidc_issuer}:sub" : "system:serviceaccount:${var.autoscaler_sa.namespace}:${var.autoscaler_sa.name}"
          }
        }
      }
    ]
  })
}

### Attach a new policy for the cluster-autoscaler role
# Based of https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
# Inspired by https://github.com/terraform-aws-modules/terraform-aws-iam/blob/263426fbb6cb8b0d59fb6b2a86168047ff1e58ac/modules/iam-role-for-service-accounts-eks/policies.tf#L48

data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.handle_iam_resources ? 1 : 0

  statement {
    actions = [
      # For cluster-autoscaler
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${aws_eks_cluster.quortex.id}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_policy" "quortex_autoscaler_policy" {
  count = var.handle_iam_resources ? 1 : 0

  description = "Allow the autoscaler to make calls to the AWS APIs."
  policy      = data.aws_iam_policy_document.cluster_autoscaler[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "quortex_autoscaler_policy_attach" {
  count      = var.handle_iam_resources ? 1 : 0
  role       = aws_iam_role.quortex_role_autoscaler[0].name
  policy_arn = aws_iam_policy.quortex_autoscaler_policy[0].arn
}
