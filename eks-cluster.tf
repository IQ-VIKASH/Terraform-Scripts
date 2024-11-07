provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "prod_vpc" {
  id = "vpc-0ced973219e4bfee3"
}

data "aws_subnet" "prod_subnet_a" {
  id = "subnet-0af1ace25d16173e4"
}

data "aws_subnet" "prod_subnet_b" {
  id = "subnet-03947941847cdeaed"
}

data "aws_security_group" "prod_eks_security_group" {
  id = "sg-0dab8a96d4db54ce9"
}

data "aws_iam_role" "eks_cluster_role" {
  name = "EKSServiceControl"
}

# EKS Cluster creation
resource "aws_eks_cluster" "wellinks_prodtest" {
  name     = "wellinks-prodtest-web-eksc"
  role_arn = data.aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = [data.aws_subnet.prod_subnet_a.id, data.aws_subnet.prod_subnet_b.id]
    security_group_ids = [data.aws_security_group.prod_eks_security_group.id]
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs    = ["0.0.0.0/0"]
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
  }

  version = "1.30"

  # Enable logging
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
}

# IAM Role for Node Group
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks_prodtest_node_group_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": { "Service": "ec2.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Attach policies for EKS managed nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"  # Corrected ARN
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}
# Managed Node Group
resource "aws_eks_node_group" "prodtest_node_group" {
  cluster_name    = aws_eks_cluster.wellinks_prodtest.name
  node_group_name = "wellinks-prodtest-web-eks-worker-node"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [data.aws_subnet.prod_subnet_a.id, data.aws_subnet.prod_subnet_b.id]

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 3
  }

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  remote_access {
    ec2_ssh_key = "worker-node-access"
    source_security_group_ids = ["sg-0c2787f530774b43b"]
  }

  disk_size = 20

  tags = {
    ENV = "PRODTEST"
  }
}

# Outputs
output "cluster_name" {
  value = aws_eks_cluster.wellinks_prodtest.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.wellinks_prodtest.endpoint
}

output "node_group_name" {
  value = aws_eks_node_group.prodtest_node_group.node_group_name
}

output "node_group_instance_types" {
  value = aws_eks_node_group.prodtest_node_group.instance_types
}


