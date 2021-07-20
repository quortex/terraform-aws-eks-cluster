
resource "aws_iam_role" "quortex_role_autoscaler" {
  count       = var.handle_iam_resources ? 1 : 0
  name        = var.worker_role_name
  description = "IAM Role to allow the autoscaler service account to manage AWS Autoscaling."
  tags        = var.tags

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.cluster_oidc_issuer}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.cluster_oidc_issuer}:sub": "system:serviceaccount:kube-system:${var.autoscaler_sa_name}"
        }
      }
    }
  ]
}
POLICY
}

### Attach a new policy for the cluster-autoscaler role

resource "aws_iam_policy" "quortex_autoscaler_policy" {
  count       = var.handle_iam_resources ? 1 : 0
  description = "Allow the autoscaler to make calls to the AWS APIs."

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

resource "aws_iam_role_policy_attachment" "quortex_autoscaler_policy_attach" {
  count      = var.handle_iam_resources ? 1 : 0
  role       = aws_iam_role.quortex_role_autoscaler[0].name
  policy_arn = aws_iam_policy.quortex_autoscaler_policy[0].arn
}
