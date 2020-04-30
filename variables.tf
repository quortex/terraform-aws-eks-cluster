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

variable "name" {
  type        = string
  description = "This value will be in the Name tag of all network resources."
  # TODO: add a default
}

variable "region" {
  type        = string
  description = "The AWS region in wich to create network regional resources (subnet, router, nat...)."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC this cluster should be attached to."
}

variable "subnet_ids_master" {
  type        = list(string)
  description = "The IDs of the subnets for the master nodes"
}

variable "subnet_ids_worker" {
  type        = list(string)
  description = "The IDs of the subnets for the worker nodes"
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
  description = "The cluster nodes instances configuration. Defined as a map where the key defines the node name, and the value is a map defining instance_types, scaling_desired_size, scaling_min_size, scaling_max_size, disk_size"
}
