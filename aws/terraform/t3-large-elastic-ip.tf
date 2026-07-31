# Look up the pre-allocated Elastic IP that is reassociated when the T3 instance
# is replaced. The allocation itself is intentionally not managed by Terraform.
data "aws_eip" "t3_large" {
  filter {
    name   = "public-ip"
    values = [var.t3_elastic_ip]
  }
}

resource "aws_eip_association" "t3_large" {
  allocation_id = data.aws_eip.t3_large.id
  instance_id   = aws_instance.t3_large.id

  lifecycle {
    prevent_destroy = true
  }
}
