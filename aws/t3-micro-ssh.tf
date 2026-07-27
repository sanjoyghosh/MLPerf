# Dedicated security group for SSH access to the t3.micro instance. The existing
# instance uses the default VPC, so this group is created in that same VPC.
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "t3_micro_ssh" {
  name        = "${var.instance_name}-ssh"
  description = "Restrict SSH access to the t3.micro instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from the approved public IPv4 CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Allow outbound IPv4 traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-ssh"
  })
}
