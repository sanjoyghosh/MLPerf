variable "aws_region" {
  description = "AWS region in which to create the EC2 instance."
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile authenticated to the intended AWS account."
  type        = string
  default     = "default"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance."
  type        = string
  default     = "t3-large-oregon"
}

variable "t3_key_name" {
  description = "Existing EC2 key pair for SSH access to the t3.large instance."
  type        = string
  default     = "sanjoy-ed25519"
}

variable "subnet_id" {
  description = "Subnet used by both the T3 and G6 instances; it fixes them in the same Availability Zone."
  type        = string
  default     = "subnet-06d1a4d69d96304bf"
}

variable "t3_elastic_ip" {
  description = "Pre-allocated Elastic IPv4 address to associate with the t3.large instance."
  type        = string
  default     = "52.11.67.245"

  validation {
    condition     = can(cidrnetmask("${var.t3_elastic_ip}/32"))
    error_message = "t3_elastic_ip must be a valid IPv4 address."
  }
}

variable "g6_spot_instance_name" {
  description = "Name tag for the g6.xlarge Spot instance."
  type        = string
  default     = "g6-xlarge-spot-oregon"
}

variable "create_g6_spot_instance" {
  description = "Whether Terraform should create the g6.xlarge Spot instance."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Public IPv4 CIDR permitted to SSH to the t3.large instance, typically your IP with /32."
  type        = string

  validation {
    condition = (
      can(cidrnetmask(var.ssh_allowed_cidr)) &&
      var.ssh_allowed_cidr != "0.0.0.0/0"
    )
    error_message = "ssh_allowed_cidr must be a specific IPv4 CIDR, not 0.0.0.0/0."
  }
}

variable "tags" {
  description = "Additional tags applied to the EC2 instance."
  type        = map(string)
  default     = {}
}

variable "ebs_volume_size_gib" {
  description = "Size of the standalone EBS volume in GiB."
  type        = number
  default     = 80

  validation {
    condition     = var.ebs_volume_size_gib >= 1
    error_message = "The EBS volume size must be at least 1 GiB."
  }
}

variable "ebs_volume_name" {
  description = "Name tag for the standalone EBS volume."
  type        = string
  default     = "t3-large-data-80gb"
}

variable "idle_cpu_threshold_percent" {
  description = "Average CPU utilization at or below which the idle-stop alarm considers the instance inactive."
  type        = number
  default     = 5

  validation {
    condition     = var.idle_cpu_threshold_percent >= 0 && var.idle_cpu_threshold_percent <= 100
    error_message = "idle_cpu_threshold_percent must be between 0 and 100."
  }
}
