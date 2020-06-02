
[![Quortex][logo]](https://quortex.io)

# terraform-aws-eks-cluster

A terraform module for Quortex infrastructure EKS cluster layer.

It provides a set of resources necessary to provision the Kubernetes cluster of the Quortex infrastructure on Amazon AWS, via EKS.

![infra_diagram]

This module is available on [Terraform Registry][registry_tf_aws-eks_cluster].

Get all our terraform modules on [Terraform Registry][registry_tf_modules] or on [Github][github_tf_modules] !

## Created resources

This module creates the following resources in AWS:

- An EKS cluster: the control plane for Kubernetes
- EKS node groups: the Kubernetes worker nodes. There are 2 variants of nodegroups:
  - node_groups: creates an EKS-managed node group (more automation, less features)
  - node_groups_advanced: creates a launch template + autoscaling group, with instances that attach to the created cluster. This provides more customization (spot instances, taints...)
- An additional security group to grant access to a list of IP addresses

## Usage example

Example that creates 1 EKS-managed node group and 1 advanced node group:

```
module "quortex-eks" {
  source = "quortex/eks-cluster/aws"
  
  region = "eu-west-3"
  name = "quortexcluster"
  kubernetes_version = "1.15"
  availability_zones = ["eu-west-3b", "eu-west-3c"]

  # values from the Quortex network module:
  subnet_ids_master = module.network.master_subnet_ids 
  subnet_ids_worker = module.network.worker_subnet_ids
  vpc_id = module.network.vpc_id
  
  master_authorized_networks = {
    myipaddress = "98.235.24.130/32"
  }

  node_groups = {
    main = {
        instance_types = ["t3.medium"] # t3.medium: 2 vCPU, 4GiB
        scaling_desired_size = 1
        scaling_max_size     = 1
        scaling_min_size     = 1
    }
  }

  node_groups_advanced = {
    workflow-group = {
      image_id             = "ami-026d2ac4b345304dc"
      instance_types       = ["c5.2xlarge","c5d.2xlarge"]
      scaling_desired_size = 2
      scaling_max_size     = 3
      scaling_min_size     = 0
      market_type          = "spot"
      taints               = {} # example taints:  {"spotinstance":"true:PreferNoSchedule"}
      labels               = {} 
    }
  }
}
```
---

## Related Projects

This project is part of our terraform modules to provision a Quortex infrastructure for AWS.

Check out these related projects.

- [terraform-aws-network][registry_tf_aws-eks_network] - A terraform module for Quortex infrastructure network layer.

- [terraform-aws-eks-cluster][registry_tf_aws-eks_cluster] - A terraform module for Quortex infrastructure AWS cluster layer.

- [terraform-aws-eks-load-balancer][registry_tf_aws-eks_load_balancer] - A terraform module for Quortex infrastructure AWS load balancing layer.

- [terraform-aws-storage][registry_tf_aws-eks_storage] - A terraform module for Quortex infrastructure AWS persistent storage layer.

## Help

**Got a question?**

File a GitHub [issue](https://github.com/quortex/terraform-aws-eks-cluster/issues) or send us an [email][email].


  [logo]: https://storage.googleapis.com/quortex-assets/logo.webp
  [infra_diagram]: https://storage.googleapis.com/quortex-assets/infra_aws_001.jpg

  [email]: mailto:info@quortex.io

  [registry_tf_modules]: https://registry.terraform.io/modules/quortex
  [registry_tf_aws-eks_network]: https://registry.terraform.io/modules/quortex/network/aws
  [registry_tf_aws-eks_cluster]: https://registry.terraform.io/modules/quortex/eks-cluster/aws
  [registry_tf_aws-eks_load_balancer]: https://registry.terraform.io/modules/quortex/load-balancer/aws
  [registry_tf_aws-eks_storage]: https://registry.terraform.io/modules/quortex/storage/aws
  [github_tf_modules]: https://github.com/quortex?q=terraform-
