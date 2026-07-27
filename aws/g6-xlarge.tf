# A one-time Spot request. AWS may interrupt and terminate this instance when
# Spot capacity is needed, so do not use it for uncheckpointed work.
resource "aws_instance" "g6_xlarge_spot" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "g6.xlarge"

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  tags = merge(var.tags, {
    Name = var.g6_spot_instance_name
  })
}
