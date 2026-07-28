# Stable public IPv4 address for the t3.large instance. Unlike an automatically
# assigned public IP, this address remains allocated across stop/start cycles.
resource "aws_eip" "t3_large" {
  domain   = "vpc"
  instance = aws_instance.t3_large.id

  tags = merge(var.tags, {
    Name = "${var.instance_name}-eip"
  })
}

