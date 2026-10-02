# https://github.com/hashicorp-education/learn-terraform-provision-eks-cluster/blob/main/main.tf

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}


###
### Permissions for Storage System EBS Driver
###
data "aws_iam_policy" "ebs_csi_policy" {
  // ARN === Amazon Resource Name
  // It is loading the IAM policy of EBS Driver
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
// irsa means IAM Roles for Service Accounts.
// It is linking specific kubernete service account to ebs role
module "irsa-ebs-csi" {

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "ebs-provisioning-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

###
### VPC 
###
module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = var.vpc_name

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

###
### Kubernetes Cluster
###
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = var.cluster_name
  cluster_version = "1.36"

  // Making Kubernetes API Server accessible from local kubectls
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  // assigning VPC to Kubernetes
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  // Control Plane : EKS Control Plane Nodes are managed by AWS, not by us
  eks_managed_node_groups = {
    one = {
      name           = "node-group"
      instance_types = ["t3.small"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }

  // Addons are spare (additional) kubernetes resources, adding some functionality and capabilities to cluster
  // In here, aws-ebs provisioner is adding into cluster
  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }
}


###
### S3 Bucket
###
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.s3_bucket_name
  tags = {
    Name = "Bucket For Drone Images"
  }
}
