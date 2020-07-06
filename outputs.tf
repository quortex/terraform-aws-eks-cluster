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

output "worker_role_arn" {
  value       = aws_iam_role.quortex_role_worker.arn
  description = "The ARN identifier of the role created in AWS for allowing the worker nodes to make calls to the AWS APIs"
}
