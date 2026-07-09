provider "aws" {
  region = "ap-south-1"
}

# ---------------------------------------------------------------
# VPC MODULE (creates private subnets automatically)
# ---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "devopsshack-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ---------------------------------------------------------------
# EKS MODULE (cluster + nodegroup + IRSA)
# ---------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"

  cluster_name    = "devopsshack-cluster"
  cluster_version = "1.29"

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]
      min_size       = 4
      max_size       = 4
      desired_size   = 4
      disk_size      = 20

      labels = {
        lifecycle = "ec2-autoscaler"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/devopsshack-cluster" = "owned"
      }
    }
  }
}

# ---------------------------------------------------------------
# ALB INGRESS CONTROLLER MODULE
# ---------------------------------------------------------------
module "alb_ingress" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version = "20.0.0"

  cluster_name = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id = module.vpc.vpc_id
}

# ---------------------------------------------------------------
# CLUSTER AUTOSCALER MODULE
# ---------------------------------------------------------------
module "cluster_autoscaler" {
  source  = "terraform-aws-modules/eks/aws//modules/cluster-autoscaler"
  version = "20.0.0"

  cluster_name = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
}

# ---------------------------------------------------------------
# CERT-MANAGER MODULE
# ---------------------------------------------------------------
module "cert_manager" {
  source  = "terraform-aws-modules/eks/aws//modules/cert-manager"
  version = "20.0.0"

  cluster_name = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
}

# ---------------------------------------------------------------
# EBS CSI DRIVER MODULE
# ---------------------------------------------------------------
module "ebs_csi" {
  source  = "terraform-aws-modules/eks/aws//modules/ebs-csi-driver"
  version = "20.0.0"

  cluster_name = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
}
