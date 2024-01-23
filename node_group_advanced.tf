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

locals {
  # instance filters
  # ALL => dont filter instances
  # PREFERRED => returns a single instance type available in the region from an ordered list of preference
  # AVAILABLE => filter instance types to keep only those available in the region
  filter_all       = "ALL"
  filter_preferred = "PREFERRED"
  filter_available = "AVAILABLE"

  # node_groups_advanced filter by instance_filter
  filtered_nodegroups_advanced_preferred = { for k, v in var.node_groups_advanced : k => v if lookup(v, "instance_filter", local.filter_all) == local.filter_preferred }
  filtered_nodegroups_advanced_available = { for k, v in var.node_groups_advanced : k => v if lookup(v, "instance_filter", local.filter_all) == local.filter_available }

  # # node_groups_advanced with filtered instance_types
  filtered_node_groups_advanced = { for k, v in var.node_groups_advanced : k =>
    lookup(v, "instance_filter", local.filter_all) == local.filter_preferred ? merge(v, tomap({ "instance_types" = [data.aws_ec2_instance_type_offering.preferred[k].instance_type] })) :
    lookup(v, "instance_filter", local.filter_all) == local.filter_available ? merge(v, tomap({ "instance_types" = [for instance_type in lookup(v, "instance_types", []) : instance_type if contains(data.aws_ec2_instance_type_offerings.available[k].instance_types, instance_type)] })) :
    v
  }
}

# Get preferred instance types for node_groups_advanced with instance_filter preferred
data "aws_ec2_instance_type_offering" "preferred" {
  for_each = local.filtered_nodegroups_advanced_preferred

  filter {
    name   = "instance-type"
    values = each.value.instance_types
  }

  preferred_instance_types = each.value.instance_types
}

# Get available instance types for node_groups_advanced with instance_filter available
data "aws_ec2_instance_type_offerings" "available" {
  for_each = local.filtered_nodegroups_advanced_available

  filter {
    name   = "instance-type"
    values = each.value.instance_types
  }
}

# Common resources

resource "aws_iam_instance_profile" "quortex" {
  count = var.handle_iam_resources ? 1 : 0
  name  = var.instance_profile_name
  role  = aws_iam_role.quortex_role_worker[0].name
}

data "aws_ami" "eks_worker_image" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.kubernetes_worker_nodes_version}-v*"]
  }
  most_recent = true
  owners      = ["self", "amazon"]
}

locals {
  ami_id_worker = coalesce(var.kubernetes_cluster_image_id, data.aws_ami.eks_worker_image.id)
}


# One launch template per node group
resource "aws_launch_template" "quortex_launch_tpl" {
  for_each = local.filtered_node_groups_advanced

  name = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")

  image_id      = local.ami_id_worker
  instance_type = each.value.instance_types[0]

  update_default_version = true

  user_data = base64encode(
    templatefile(
      "${path.module}/userdata.sh.tpl",
      {
        warm_pool = lookup(each.value, "warm_pool_enabled", false)
        script = templatefile("${path.module}/cluster_connect.sh.tpl",
          {
            cluster_name       = aws_eks_cluster.quortex.name
            base64_cluster_ca  = aws_eks_cluster.quortex.certificate_authority[0].data
            api_server_url     = aws_eks_cluster.quortex.endpoint
            kubelet_extra_args = lookup(each.value, "kubelet_extra_args", "")
            # define the k8s node taints (passed to --kubelet-extra-args)
            node_taints = length(each.value.taints) == 0 ? "" : join(",", [for k, v in lookup(each.value, "taints", {}) : "${k}=${v}"])
            # define the k8s node labels (passed to --kubelet-extra-args)
            node_labels = join(
              ",",
              [
                for k, v in
                merge(
                  # Built-in labels
                  {
                    "eks.amazonaws.com/nodegroup-image" = local.ami_id_worker,
                    "eks.amazonaws.com/nodegroup"       = each.key,
                    "nodegroup"                         = each.key
                  },
                  # User-specified labels
                  lookup(each.value, "labels", {}),
                )
              : "${k}=${v}"]
            )
            use_max_pods = var.node_use_max_pods
          }
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
    name = var.handle_iam_resources ? aws_iam_instance_profile.quortex[0].name : var.instance_profile_name
  }

  vpc_security_group_ids = flatten([
    aws_eks_cluster.quortex.vpc_config[0].cluster_security_group_id, # the cluster security group (created by EKS)
    aws_security_group.remote_access[*].id                           # the SSH security group
  ])

  key_name = var.remote_access_ssh_key

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = lookup(each.value, "imdsv2_required", true) ? "required" : "optional"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  tags = merge(
    {
      "nodegroup" = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")
    },
    var.tags
  )

}

# For each node group, create an autoscaling group based on the launch template
resource "aws_autoscaling_group" "quortex_asg_advanced" {
  for_each = local.filtered_node_groups_advanced

  name                = lookup(each.value, "asg_name", "${var.cluster_name}_${each.key}")
  vpc_zone_identifier = lookup(each.value, "subnet_ids", [])
  desired_capacity    = lookup(each.value, "scaling_desired_size", lookup(each.value, "scaling_min_size", 1))
  max_size            = lookup(each.value, "scaling_max_size", 1)
  min_size            = lookup(each.value, "scaling_min_size", 1)
  enabled_metrics     = lookup(each.value, "enabled_metrics", [])

  lifecycle {
    ignore_changes = [
      # ignore changes to the cluster size, because it can be changed by autoscaling
      desired_capacity,
      load_balancers,
      target_group_arns
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

  # Only for Warm-Pool instance groups:
  dynamic "warm_pool" {
    for_each = lookup(each.value, "warm_pool_enabled", false) ? [true] : []
    content {
      pool_state                  = "Stopped"
      min_size                    = lookup(each.value, "warm_pool_min_size", 0)
      max_group_prepared_capacity = lookup(each.value, "warm_pool_max_prepared_capacity", 0)
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
        spot_instance_pools                      = lookup(each.value, "spot_instance_pools", 0)
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
      # these tags are used to enable autoscaling for this ASG:
      {
        "k8s.io/cluster-autoscaler/enabled"                       = true
        "k8s.io/cluster-autoscaler/${var.cluster_name}"           = "owned"
        "k8s.io/cluster-autoscaler/node-template/label/nodegroup" = each.key
      },
      # the following tags must be set on the ASG, and must match the k8s node labels/taints, for the autoscaler to be able to scale up from 0
      { for k, v in lookup(each.value, "labels", {}) : "k8s.io/cluster-autoscaler/node-template/label/${k}" => v },
      { for k, v in lookup(each.value, "taints", {}) : "k8s.io/cluster-autoscaler/node-template/taint/${k}" => v },
    ) : {}
    iterator = tag

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # user defined tags
  dynamic "tag" {
    for_each = merge(
      var.tags,
      var.compute_tags,
      lookup(each.value, "tags", {})
    )
    iterator = tag

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [kubernetes_config_map_v1_data.aws_auth]
}
