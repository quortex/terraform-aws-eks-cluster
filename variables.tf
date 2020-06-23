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

variable "cluster_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the cluster"
  default     = "quortex"
}

variable "master_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the master role"
  default     = "quortex-master"
}

variable "worker_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the worker role"
  default     = "quortex-worker"
}

variable "autoscaler_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the autoscaler role"
  default     = "quortex-autoscaler"
}

variable "region" {
  type        = string
  description = "The AWS region in wich to create network regional resources (subnet, router, nat...)."
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes master version."
  default     = "1.15"
}

variable "kubernetes_cluster_version" {
  type        = string
  description = "Kubernetes version for worker nodes"
  default     = "1.15"
}

variable "kubernetes_cluster_image_id" {
  type        = string
  description = "ID of the AMI to use for worker nodes (applies only to advanced_node_groups). If not defined, the latest AMI whose name matches \"amazon-eks-node-<kubernetes_cluster_version>-v*\" will be used"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC this cluster should be attached to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "The IDs of the subnets where nodes should be placed"
}

variable "subnet_ids_worker" {
  type        = list(string)
  description = "The IDs of the subnets where worker nodes should be placed. By default, the subnets are subnet_ids"
  default     = []
}

variable "master_authorized_networks" {
  type        = map(string)
  description = "External networks that can access the Kubernetes cluster master through HTTPS. This is a dictionary where the value is the CIDR block of the authorized range."
  default     = {}
}

variable "tags" {
  type        = map
  description = "The EKS resource tags (a map of key/value pairs) to be applied to the cluster."
  default     = {}
}

variable "node_groups" {
  type        = map(any)
  description = "EKS-managed node groups. The nodes are attached automatically to the cluster via EKS. Defined as a map where the key defines the node group name, and the value is a map defining instance_types, scaling_desired_size, scaling_min_size, scaling_max_size, disk_size"
}

variable "node_groups_advanced" {
  type        = map(any)
  description = "[EXPERIMENTAL] Node groups that are not managed via EKS. The nodes are attached to the cluster with userdata passed to the instance boot script. More options are available than with EKS-managed node groups (taints, spot instances...). Defined as a map where the key defines the node group name, and the value is a map containing the node group parameters."
}

variable "instance_profile_name" {
  type        = string
  description = "A name for the instance profile resource in AWS. Used only when node_groups_advanced is used."
  default     = "quortex"
}

variable "remote_access_ssh_key" {
  type        = string
  description = "Configure SSH access to the nodes. Specify a key pair name that exists in AWS EC2."
  default     = null
}

variable "remote_access_allowed_ip_ranges" {
  type        = list(string)
  description = "List of IP CIDR blocks allowed to access the nodes via SSH"
  default     = []
}
