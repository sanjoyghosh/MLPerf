# EBS volumes can only be attached to instances in the same Availability Zone.
# This volume is created alongside the instance but is not attached automatically.
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.t3_large.availability_zone
  size              = var.ebs_volume_size_gib
  type              = "gp3"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name = var.ebs_volume_name
  })
}
