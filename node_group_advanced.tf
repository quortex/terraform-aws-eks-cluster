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

  name = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")

  image_id = each.value.image_id
  # If multiple instance types are required, the instance type can be overridden in the autoscaling group
  instance_type = each.value.instance_types[0] # TODO: add possibility to specify multiple instance types ("mixed instance")

  dynamic "instance_market_options" {
    for_each = each.value.market_type == "spot" ? [true] : []

    content {
      market_type = "spot"
    }
  }


  user_data = base64encode(
    templatefile(
      "${path.module}/userdata.sh.tpl",
      {
        cluster_name            = aws_eks_cluster.quortex.name
        base64_cluster_ca       = aws_eks_cluster.quortex.certificate_authority[0].data
        api_server_url          = aws_eks_cluster.quortex.endpoint
        kubelet_more_extra_args = ""
        node_taints             = length(each.value.taints) == 0 ? "" : join(",", [for k, v in lookup(each.value, "taints", {}) : "${k}=${v}"])
        node_labels = join(
          ",",
          [
            for k, v in
            merge(
              # Built-in labels
              map(
                "eks.amazonaws.com/nodegroup-image", each.value.image_id,
                "eks.amazonaws.com/nodegroup", each.key,
                "nodegroup", each.key
              ),
              # User-specified labels
              lookup(each.value, "labels", {}),
            )
          : "${k}=${v}"]
        )
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

  vpc_security_group_ids = flatten([
    aws_eks_cluster.quortex.vpc_config[0].cluster_security_group_id, # the cluster security group (created by EKS)
    aws_security_group.remote_access[*].id                           # the SSH security group
  ])

  key_name = var.remote_access_ssh_key

}

# For each node group, create an autoscaling group based on the launch template
resource "aws_autoscaling_group" "quortex_asg_advanced" {
  for_each = var.node_groups_advanced

  name                = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")
  vpc_zone_identifier = var.subnet_ids_worker
  desired_capacity    = each.value.scaling_desired_size
  max_size            = each.value.scaling_max_size
  min_size            = each.value.scaling_min_size

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

  tag {
    key                 = "eks:cluster-name"
    propagate_at_launch = true
    value               = var.cluster_name
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

  # built-in labels

  tag {
    key                 = "nodegroup"
    value               = each.key
    propagate_at_launch = true
  }

  tag { # tag required for scaling to/from 0
    key                 = "k8s.io/cluster-autoscaler/node-template/label/nodegroup"
    value               = each.key
    propagate_at_launch = true
  }


  # user-defined labels
  dynamic "tag" {
    for_each = lookup(each.value, "labels", {})
    iterator = label

    content {
      key                 = "k8s.io/cluster-autoscaler/node-template/label/${label.key}"
      value               = label.value
      propagate_at_launch = true
    }
  }

  # taints
  dynamic "tag" {
    for_each = lookup(each.value, "taints", {})
    iterator = taint

    content {
      key                 = "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}"
      value               = taint.value
      propagate_at_launch = true
    }
  }

}
