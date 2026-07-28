terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Uses the current official Ubuntu 24.04 LTS (Noble) x86_64 server AMI published
# by Canonical. Canonical's AWS owner ID is documented at ubuntu.com/aws.
data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "t3_large" {
  ami                    = data.aws_ami.ubuntu_2404.id
  instance_type          = "t3.large"
  key_name               = var.t3_key_name
  vpc_security_group_ids = [aws_security_group.t3_large_ssh.id]

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

# Preserve the existing instance in Terraform state when moving from t3.micro.
moved {
  from = aws_instance.t3_micro
  to   = aws_instance.t3_large
}
