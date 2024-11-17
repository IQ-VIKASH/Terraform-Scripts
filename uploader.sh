#!/bin/bash

S3_BUCKET_NAME="backupeksclusterymlfile"

current_date=$(date +%Y-%m-%d)

namespaces=(
    "webhttp"
    "adaptor-assessment-api"
    "adaptor-commonutil-api"
    "adaptor-communication-api"
    "adaptor-integration-api"
    "adaptor-patients-api"
    "adaptor-pgi-api"
    "adaptor-task-api"
    "adaptor-users-api"
    "exp-appointhttps-api"
    "exp-appointment-api"
    "exp-assessment-api"
    "exp-commonutil-api"
    "exp-patient-api"
    "exp-pgi-api"
    "exp-task-api"
    "exp-users-api"
)

backup_dir="./k8s-backup-${current_date}"
mkdir -p "$backup_dir"

for ns in "${namespaces[@]}"; do
    backup_file="${backup_dir}/${ns}-backup-${current_date}.yaml"
    kubectl get all --namespace "$ns" -o yaml > "$backup_file"
    aws s3 cp "$backup_file" "s3://$S3_BUCKET_NAME/$current_date/${ns}-backup-${current_date}.yaml"
done


provider "aws" {
  region = "us-west-2"
}

# Generate SSH key pair and save locally
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "ssh_private_key" {
  filename = "${path.module}/ec2-key.pem"
  content  = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the default VPC's default subnet
data "aws_subnet_ids" "default_subnets" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnet" "default_subnet" {
  id = tolist(data.aws_subnet_ids.default_subnets.ids)[0]
}

# Security group to allow SSH access
resource "aws_security_group" "ssh_access" {
  name_prefix = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.aws_vpc.default.id
}

# EC2 instance
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (example for us-west-2)
  instance_type = "t2.micro"

  key_name               = aws_key_pair.ec2_key.key_name
  security_groups        = [aws_security_group.ssh_access.name]
  subnet_id              = data.aws_subnet.default_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "example-instance"
  }
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.example.public_ip
}

output "ssh_private_key_path" {
  description = "Path to the private SSH key"
  value       = local_file.ssh_private_key.filename
}

