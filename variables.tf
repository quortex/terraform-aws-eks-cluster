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
  description = "A name to be used as the AWS resource name for the IAM role used by EKS managed worker nodes"
  default     = "quortex-worker-managed"
}

variable "autoscaler_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the autoscaler role"
  default     = "quortex-autoscaler"
}

variable "autoscaler_sa" {
  description = "Service Account name for Autoscaler"

  type = object({
    namespace = string
    name      = string
  })
  default = {
    namespace = "kube-system"
    name      = "cluster-autoscaler-sa"
  }
}

variable "ebs_csi_driver_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the Amazon EBS CSI Driver role."
  default     = "quortex-ebs-csi-driver"
}

variable "ebs_csi_driver_sa" {
  description = "Service Account name for EBS CSI Driver"

  type = object({
    namespace = string
    name      = string
  })
  default = {
    namespace = "kube-system"
    name      = "ebs-csi-controller-sa"
  }
}

variable "aws_vpc_cni_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the Amazon VPC CNI role."
  default     = "quortex-vpc-cni"
}

variable "aws_vpc_cni_sa" {
  description = "Service Account name for Amazon VPC CNI"

  type = object({
    namespace = string
    name      = string
  })
  default = {
    namespace = "kube-system"
    name      = "aws-node"
  }
}

variable "aws_load_balancer_controller_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the aws-load-balancer-controller role."
  default     = "quortex-aws-load-balancer-controller"
}

variable "aws_load_balancer_controller_sa" {
  description = "Service Account name for aws-load-balancer-controller"

  type = object({
    namespace = string
    name      = string
  })
  default = {
    namespace = "kube-system"
    name      = "aws-load-balancer-controller"
  }
}

variable "external_dns_role_name" {
  type        = string
  description = "A name to be used as the AWS resource name for the external-dns role."
  default     = "quortex-external-dns"
}

variable "external_dns_sa" {
  description = "Service Account name for external-dns"

  type = object({
    namespace = string
    name      = string
  })

  default = {
    namespace = "kube-system"
    name      = "external-dns"
  }
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes master version."
  default     = "1.22"
}

variable "kubernetes_worker_nodes_version" {
  type        = string
  description = "Kubernetes version for worker nodes. An empty string means the same Kubernetes version as the master's"
  default     = ""
}

locals {
  kubernetes_worker_nodes_version = var.kubernetes_worker_nodes_version == "" ? var.kubernetes_version : var.kubernetes_worker_nodes_version
}

variable "kubernetes_cluster_image_id" {
  type        = string
  description = "ID of the AMI to use for worker nodes (applies only to advanced_node_groups). If not defined, the latest AMI whose name matches \"amazon-eks-node-<kubernetes_worker_nodes_version>-v*\" will be used"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC this cluster should be attached to."
}

variable "master_subnet_ids" {
  type        = list(string)
  description = "The IDs of the subnets where master should be placed"
  default     = []
}

variable "master_authorized_networks" {
  type        = map(string)
  description = "External networks that can access the Kubernetes cluster master through HTTPS. This is a dictionary where the value is the CIDR block of the authorized range."
  default     = {}
}

variable "pods_subnets" {
  type        = map(object({ id = string, availability_zone = string, cidr = string, public = bool }))
  description = <<EOT
A map representing the pods subnets. Each item contains the subnet's ID,
Availability Zone, cidr block, and whether the subnet is public or not.
EOT
  default     = {}
}

variable "handle_eni_configs" {
  type        = bool
  description = "To determine if eniconfig resources should be managed by this module"
  default     = false
}

variable "tags" {
  type        = map(any)
  description = "The EKS resource tags (a map of key/value pairs) to be applied to the cluster."
  default     = {}
}

variable "compute_tags" {
  type        = map(any)
  description = "The EKS resource tags (a map of key/value pairs) to be applied to the cluster's compute resources only."
  default     = {}
}

variable "node_groups" {
  type        = map(any)
  description = "EKS-managed node groups. The nodes are attached automatically to the cluster via EKS. Defined as a map where the key defines the node group name, and the value is a map defining instance_types, scaling_desired_size, scaling_min_size, scaling_max_size, disk_size, cluster_autoscaler_enabled"
}

variable "node_groups_advanced" {
  type        = map(any)
  description = "[EXPERIMENTAL] Node groups that are not managed via EKS. The nodes are attached to the cluster with userdata passed to the instance boot script. More options are available than with EKS-managed node groups (taints, spot instances...). Defined as a map where the key defines the node group name, and the value is a map containing the node group parameters."
}

variable "node_use_max_pods" {
  type        = bool
  default     = true
  description = "Set to false to prevent EKS from setting --max-pods in Kubelet config. By default, EKS sets the maximum number of pods that can run on the node, based on the instance type. Disabling this can be useful when using a CNI other than the default, like Calico."
}

variable "discard_unpacked_layers" {
  type        = bool
  default     = true
  description = "Set to false to keep unpacked layers on the node after the image is pulled. By default, EKS will clean up the unpacked layers to save disk space."
}

variable "ami_al2023" {
  description = "Whether to use Amazon Linux 2023 AMI for worker nodes (only applies to advanced_node_groups)."
  type        = bool
  default     = false
}

variable "node_use_max_pods_allowed" {
  type        = bool
  default     = false
  description = "Set to use max number of pods allowed to run in node instead of recommended value"
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

variable "handle_iam_resources" {
  type        = bool
  description = "Wether to handle IAM resource lifecycle (master role / worker role / IAM instance profile for worker nodes...)"
  default     = true
}

variable "handle_iam_ebs_csi_driver" {
  type        = bool
  description = "Wether to handle IAM resources lifecycle for Amazon EBS CSI Driver"
  default     = true
}

variable "handle_iam_aws_vpc_cni" {
  type        = bool
  description = "Wether to handle IAM resources lifecycle for Amazon VPC CNI"
  default     = true
}

variable "handle_iam_aws_load_balancer_controller" {
  type        = bool
  description = "Whether to handle IAM resources lifecycle for aws-load-balancer-controller addon"
  default     = false
}

variable "handle_iam_cluster_autoscaler" {
  type        = bool
  description = "Wether to handle IAM resources lifecycle for cluster-autoscaler"
  default     = true
}

variable "handle_iam_external_dns" {
  type        = bool
  description = "Whether to handle IAM resources lifecycle for external-dns addon"
  default     = false
}

variable "master_role_arn" {
  type        = string
  description = "The ARN of a role with the necessary permissions for EKS master. (to be used with handle_iam_resources = false)"
  default     = ""
}

variable "worker_role_arn" {
  type        = string
  description = "The ARN of a role with the necessary permissions for EKS workers. (to be used with handle_iam_resources = false)"
  default     = ""
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "List of the desired control plane logging to enable. For more information, see Amazon EKS Control Plane Logging (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)."
  default     = []
}

variable "cluster_logs_retention" {
  type        = number
  description = "Specifies the number of days you want to retain log events for the cluster logs log group."
  default     = 7
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster.`"
  type        = any
  default     = {}
}

variable "vpc_cni_addon" {
  description = "vpc-cni addon definition"
  type = object({
    version              = string
    resolve_conflicts    = optional(string, "OVERWRITE")
    preserve             = optional(bool)
    configuration_values = any
  })
  nullable = true
}

variable "manage_aws_auth_configmap" {
  description = "Determines whether to manage the aws-auth configmap."
  type        = bool
  default     = false
}

variable "create_aws_auth_configmap" {
  description = "Determines whether to create the aws-auth configmap. NOTE - this is only intended for scenarios where the configmap does not exist (i.e. - when using only self-managed node groups)."
  type        = bool
  default     = false
}

variable "aws_auth_roles" {
  description = "List of role maps to add to the aws-auth configmap. For more information, see https://github.com/kubernetes-sigs/aws-iam-authenticator#full-configuration-format."
  type        = list(any)
  default     = []
}

variable "aws_auth_users" {
  description = "List of user maps to add to the aws-auth configmap. For more information, see https://github.com/kubernetes-sigs/aws-iam-authenticator#full-configuration-format."
  type        = list(any)
  default     = []
}

variable "aws_auth_accounts" {
  description = "List of account maps to add to the aws-auth configmap. For more information, see https://github.com/kubernetes-sigs/aws-iam-authenticator#full-configuration-format."
  type        = list(any)
  default     = []
}

variable "cluster_security_group_additional_rules" {
  description = "Additional rules for cluster security group."
  type = map(object({
    description              = optional(string)
    protocol                 = string
    type                     = string
    from_port                = number
    to_port                  = number
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    prefix_list_ids          = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = {}
}
