# Reserve a stable public IPv4 address before the optional G6 Spot instance is
# created. It is associated only while that instance exists.
resource "aws_eip" "g6_xlarge" {
  domain = "vpc"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.g6_spot_instance_name}-eip"
  })
}

resource "aws_eip_association" "g6_xlarge" {
  count = var.create_g6_spot_instance ? 1 : 0

  allocation_id = aws_eip.g6_xlarge.id
  instance_id   = aws_instance.g6_xlarge_spot[0].id
}

# Retain the existing allocated EIP if this configuration is updated after a
# G6 instance was previously created with the original count-based resource.
moved {
  from = aws_eip.g6_xlarge[0]
  to   = aws_eip.g6_xlarge
}
