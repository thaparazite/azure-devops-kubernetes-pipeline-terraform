# aws --version
# aws eks --region eu-west-1 update-kubeconfig --name sketysoft-cluster
# Uses default VPC and Subnet. For production, create your own VPC and private subnets.
# terraform-backend-state-sketysoft
# (Remove any sensitive keys from code and use environment variables or secret managers)

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.25" }
  }
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "eu-west-1"
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

module "sketysoft-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "sketysoft-cluster"
  cluster_version = "1.29"
  subnets         = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      min_size       = 2
      max_size       = 5
      desired_size   = 3
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.sketysoft-cluster.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.sketysoft-cluster.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}
