# A one-time Spot request. AWS may interrupt and terminate this instance when
# Spot capacity is needed, so do not use it for uncheckpointed work.
resource "aws_instance" "g6_xlarge_spot" {
  count = var.create_g6_spot_instance ? 1 : 0

  ami                    = data.aws_ami.ubuntu_2404.id
  instance_type          = "g6.xlarge"
  key_name               = var.t3_key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.t3_large_ssh.id]

  root_block_device {
    delete_on_termination = false
  }

  # Reject future plans that would delete or replace the G6 instance.
  lifecycle {
    prevent_destroy = true
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type             = "persistent"
      instance_interruption_behavior = "terminate"
    }
  }

  tags = merge(var.tags, {
    Name = var.g6_spot_instance_name
  })
}
