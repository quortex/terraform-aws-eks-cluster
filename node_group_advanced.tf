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

data "aws_ami" "eks_worker_image" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.kubernetes_cluster_version}-v*"]
  }
  most_recent = true
  owners      = ["self", "amazon"]
}

locals {
  ami_id_worker = coalesce(var.kubernetes_cluster_image_id, data.aws_ami.eks_worker_image.id)
}


# One launch template per node group
resource "aws_launch_template" "quortex_launch_tpl" {
  for_each = var.node_groups_advanced

  name = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")

  image_id      = local.ami_id_worker
  instance_type = each.value.instance_types[0]

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
                "eks.amazonaws.com/nodegroup-image", local.ami_id_worker,
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
    device_name = lookup(each.value, "block_device_name", "/dev/xvda")

    ebs {
      delete_on_termination = lookup(each.value, "block_device_delete_on_termination", true)
      volume_size           = lookup(each.value, "block_device_size_gb", 20)
      volume_type           = lookup(each.value, "block_device_type", "gp2")
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

  tags = merge(
    map(
      "nodegroup", lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")
    ),
    var.tags
  )

}

# For each node group, create an autoscaling group based on the launch template
resource "aws_autoscaling_group" "quortex_asg_advanced" {
  for_each = var.node_groups_advanced

  name                = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")
  vpc_zone_identifier = length(var.subnet_ids_worker) != 0 ? var.subnet_ids_worker : var.subnet_ids
  desired_capacity    = lookup(each.value, "scaling_desired_size", lookup(each.value, "scaling_min_size", 1))
  max_size            = lookup(each.value, "scaling_max_size", 1)
  min_size            = lookup(each.value, "scaling_min_size", 1)
  enabled_metrics     = lookup(each.value, "enabled_metrics", [])

  lifecycle {
    ignore_changes = [
      # ignore changes to the cluster size, because it can be changed by autoscaling
      desired_capacity,
    ]
  }

  # Only for On-Demand instance groups:
  dynamic "launch_template" {
    for_each = each.value.market_type == "on-demand" ? [true] : []

    content {
      id      = aws_launch_template.quortex_launch_tpl[each.key].id
      version = "$Latest"
    }
  }

  # Only for Spot instance groups:
  dynamic "mixed_instances_policy" {
    for_each = each.value.market_type == "spot" ? [true] : []

    content {

      instances_distribution {
        on_demand_base_capacity                  = lookup(each.value, "on_demand_base_capacity", 0)
        on_demand_percentage_above_base_capacity = lookup(each.value, "on_demand_percentage_above_base_capacity", 0)
        spot_allocation_strategy                 = lookup(each.value, "spot_allocation_strategy", "capacity-optimized")
        spot_max_price                           = lookup(each.value, "spot_max_price", "")
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.quortex_launch_tpl[each.key].id
          version            = "$Latest"
        }

        dynamic "override" {
          for_each = each.value.instance_types
          content {
            instance_type = override.value
          }
        }

      }
    }
  }


  tag {
    key                 = "eks:cluster-name"
    propagate_at_launch = true
    value               = var.cluster_name
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

  # tag the ASG with "spot" key
  tag {
    key                 = "spot"
    value               = each.value.market_type == "spot" ? "yes" : "no"
    propagate_at_launch = false
  }

  # cluster-autoscaler related tags
  dynamic "tag" {
    for_each = lookup(each.value, "cluster_autoscaler_enabled", true) ? merge(
      {
        "k8s.io/cluster-autoscaler/enabled"                       = true
        "k8s.io/cluster-autoscaler/${var.cluster_name}"           = "owned"
        "k8s.io/cluster-autoscaler/node-template/label/nodegroup" = each.key
      },
      { for k, v in lookup(each.value, "labels", {}) : "k8s.io/cluster-autoscaler/node-template/label/${k}" => v },
      { for k, v in lookup(each.value, "taints", {}) : "k8s.io/cluster-autoscaler/node-template/taint/${k}" => v }
    ) : {}
    iterator = tag

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
