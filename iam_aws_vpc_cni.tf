locals {
  handle_aws_vpc_cni = var.handle_iam_resources && var.handle_iam_aws_vpc_cni
}

resource "aws_iam_role" "aws_vpc_cni" {
  count       = local.handle_aws_vpc_cni ? 1 : 0
  name        = var.aws_vpc_cni_role_name
  description = "IAM Role required for Amazon VPC CNI."

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
            "${local.cluster_oidc_issuer}:sub" : "system:serviceaccount:${var.aws_vpc_cni_sa.namespace}:${var.aws_vpc_cni_sa.name}"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_vpc_cni" {
  count      = local.handle_aws_vpc_cni ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.aws_vpc_cni[0].name
}
