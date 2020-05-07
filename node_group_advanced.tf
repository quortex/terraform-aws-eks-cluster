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

# Common resources

resource "aws_iam_instance_profile" "quortex" {
  name = var.instance_profile_name
  role = aws_iam_role.quortex_role_worker.name
}


# One launch template per node group
resource "aws_launch_template" "quortex_launch_tpl" {
  for_each = var.node_groups_advanced

  name = "${aws_eks_cluster.quortex.name}-${each.key}"

  image_id = each.value.image_id
  # If multiple instance types are required, the instance type can be overridden in the autoscaling group
  instance_type = each.value.instance_types[0] # TODO: add possibility to specify multiple instance types ("mixed instance")

  dynamic "instance_market_options" {
    for_each = each.value.market_type == "spot" ? [true] : []

    content {
      market_type = "spot"
    }
  }

  tags = {
    "eks:cluster-name"   = aws_eks_cluster.quortex.name
    "eks:nodegroup-name" = each.key
  }

  user_data = base64encode(
    templatefile(
      "${path.module}/userdata.sh.tpl",
      {
        cluster_name            = aws_eks_cluster.quortex.name
        ami_id                  = each.value.image_id
        nodegroup_name          = each.key
        base64_cluster_ca       = aws_eks_cluster.quortex.certificate_authority[0].data
        api_server_url          = aws_eks_cluster.quortex.endpoint
        kubelet_more_extra_args = length(each.value.taints) == 0 ? "" : "--register-with-taints=${join(",", each.value.taints)}"
      }
    )
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = "true"
      iops                  = 0
      volume_size           = 20
      volume_type           = "gp2"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.quortex.name
  }

  dynamic "network_interfaces" {
    for_each = var.subnet_ids_worker
    iterator = subnet_id

    content {
      delete_on_termination = true
      subnet_id             = subnet_id.value
      security_groups = flatten([
        # the cluster security group (created by EKS)
        aws_eks_cluster.quortex.vpc_config[0].cluster_security_group_id,
        # the SSH security group
        aws_security_group.remote_access[*].id
      ])
    }
  }

  key_name = var.remote_access_ssh_key # TODO: test when it is not defined (null)

}

# For each node group, create an autoscaling group based on the launch template
resource "aws_autoscaling_group" "quortex_asg_advanced" {
  for_each = var.node_groups_advanced

  name = each.key

  availability_zones = var.availability_zones
  desired_capacity   = each.value.scaling_desired_size
  max_size           = each.value.scaling_max_size
  min_size           = each.value.scaling_min_size

  lifecycle {
    ignore_changes = [
      # ignore changes to the cluster size, because it can be changed by autoscaling
      desired_capacity,
    ]
  }

  launch_template {
    id      = aws_launch_template.quortex_launch_tpl[each.key].id
    version = "$Latest"
  }

  # These "eks:" tags might not be required, they are usually set when EKS is managing the node group, here we are trying to replicate the same
  tag {
    key                 = "eks:cluster-name"
    propagate_at_launch = true
    value               = var.cluster_name
  }
  tag {
    key                 = "eks:nodegroup-name"
    propagate_at_launch = true
    value               = each.key
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    propagate_at_launch = true
    value               = "true"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    propagate_at_launch = true
    value               = "owned"
  }

  # Tag required to join the cluster
  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    propagate_at_launch = true
    value               = "owned"
  }

}
