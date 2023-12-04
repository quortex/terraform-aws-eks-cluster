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

output "autoscaling_group_names" {
  value = concat(
    # Retrieve the autoscaling group names from the EKS-managed node groups
    flatten(
      [for node_group in aws_eks_node_group.quortex : [for r in node_group.resources : [for g in r.autoscaling_groups : g.name]]]
    ),
    # Retrieve the non-managed autoscaling group names
    [for name, v in aws_autoscaling_group.quortex_asg_advanced : v.name]
  )
  description = "The names of the created autoscaling groups"
}

output "autoscaling_group_names_map" {
  value = {
    "managed"  = { for k, v in aws_eks_node_group.quortex : k => try(v.resources[0].autoscaling_groups[0].name, "") },
    "advanced" = { for k, v in aws_autoscaling_group.quortex_asg_advanced : k => v.name }
  }
  description = "A map containing the names of the created autoscaling groups."
}

output "node_groups_names" {
  value       = { for k, v in aws_eks_node_group.quortex : k => v.node_group_name }
  description = "A map with node groups names for each node_groups provided in variables."
}

output "autoscaling_groups_names" {
  value       = { for k, v in aws_autoscaling_group.quortex_asg_advanced : k => v.name }
  description = "A map with autoscaling groups names for each node_groups_advanced provided in variables."
}

output "cluster_security_group_id" {
  value       = aws_eks_cluster.quortex.vpc_config[0].cluster_security_group_id
  description = "The cluster security group that was created by Amazon EKS for the cluster."
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.quortex.certificate_authority[0].data
  description = "The base64 encoded certificate data required to communicate with the cluster."
  sensitive   = true
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.quortex.endpoint
  description = "The endpoint for the Kubernetes API server."
}

output "cluster_oidc_issuer_url" {
  value       = try(aws_eks_cluster.quortex.identity[0].oidc[0].issuer, null)
  description = "URL of Kubernetes OpenID Connect Issuer."
}

output "worker_role_arn" {
  value       = length(aws_iam_role.quortex_role_worker) > 0 ? aws_iam_role.quortex_role_worker[0].arn : null
  description = "The ARN identifier of the role created in AWS for allowing the worker nodes to make calls to the AWS APIs"
}

output "ebs_csi_driver_role_arn" {
  value       = try(aws_iam_role.ebs_csi_driver[0].arn, null)
  description = "The ARN identifier of the role created in AWS for the Amazon EBS CSI driver."
}

output "cluster_autoscaler_role_arn" {
  value       = try(aws_iam_role.quortex_role_autoscaler[0].arn, null)
  description = "The ARN identifier of the role created in AWS for the Cluster Autoscaler."
}

output "aws_load_balancer_controller_role_arn" {
  value       = try(aws_iam_role.aws_load_balancer_controller[0].arn, null)
  description = "The ARN identifier of the role created in AWS for the aws-load-balancer-controller."
}
