output "instance_id" {
  description = "ID of the created EC2 instance."
  value       = aws_instance.t3_micro.id
}

output "g6_spot_instance_id" {
  description = "ID of the g6.xlarge Spot instance."
  value       = aws_instance.g6_xlarge_spot.id
}

output "public_ip" {
  description = "Public IPv4 address, if the selected default subnet assigns one."
  value       = aws_instance.t3_micro.public_ip
}

output "ebs_volume_id" {
  description = "ID of the standalone 80 GiB EBS volume."
  value       = aws_ebs_volume.data.id
}
