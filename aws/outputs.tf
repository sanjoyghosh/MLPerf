output "instance_id" {
  description = "ID of the created EC2 instance."
  value       = aws_instance.t3_large.id
}

output "g6_spot_instance_id" {
  description = "ID of the g6.xlarge Spot instance."
  value       = var.create_g6_spot_instance ? aws_instance.g6_xlarge_spot[0].id : null
}

output "public_ip" {
  description = "Public IPv4 address, if the selected default subnet assigns one."
  value       = aws_instance.t3_large.public_ip
}

output "t3_large_elastic_ip" {
  description = "Stable Elastic IP address associated with the t3.large instance."
  value       = data.aws_eip.t3_large.public_ip
}

output "ebs_volume_id" {
  description = "ID of the standalone 80 GiB EBS volume."
  value       = aws_ebs_volume.data.id
}
