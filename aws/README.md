# EC2 instance commands

Run these commands from the repository root after `terraform apply` has created the instance:

```bash
./aws/ec2-t3-micro.sh status
./aws/ec2-t3-micro.sh stop
./aws/ec2-t3-micro.sh start
./aws/ec2-t3-micro.sh terminate
```

The script reads the instance ID, AWS profile, and region from the Terraform configuration and state. The IAM principal also needs `ec2:StartInstances`, `ec2:StopInstances`, `ec2:TerminateInstances`, and `ec2:DescribeInstances` permissions. `terminate` permanently deletes the instance.

## SSH key import

Import the local `~/.ssh/id_ed25519.pub` key as `sanjoy-ed25519` in `us-west-2`:

```bash
./aws/setup-vm.sh
```

Optionally provide a different EC2 key-pair name and public-key path:

```bash
./aws/setup-vm.sh my-key ~/.ssh/another-key.pub
```

## SSH access

The `t3.micro` uses a dedicated Terraform-managed security group. Set `ssh_allowed_cidr` in `terraform.tfvars` to your current public IPv4 address with a `/32` suffix, then run `terraform apply`:

```bash
curl -4 https://checkip.global.api.aws/
# Example terraform.tfvars value: ssh_allowed_cidr = "198.51.100.42/32"
```

The IAM principal needs `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:AuthorizeSecurityGroupEgress`, and `ec2:DeleteSecurityGroup` permissions.

The `t3.micro` is configured to use the `sanjoy-ed25519` EC2 key pair. Adding or changing an EC2 key pair requires Terraform to replace an existing instance. Detach the standalone EBS volume before applying this change if it is attached.

## Stable SSH address

Terraform allocates an Elastic IP for the `t3.micro`, preserving its public address across stop/start cycles. After applying, retrieve it and use it as `HostName` in `~/.ssh/config`:

```bash
terraform -chdir=aws output -raw t3_elastic_ip
```

The IAM principal needs `ec2:AllocateAddress`, `ec2:AssociateAddress`, `ec2:DisassociateAddress`, `ec2:ReleaseAddress`, and `ec2:DescribeAddresses` permissions.

## EBS volume

`terraform apply` also creates a standalone 80 GiB `gp3` EBS volume in the same Availability Zone as the EC2 instance. It is not attached to the instance. The IAM principal needs `ec2:CreateVolume`, `ec2:DescribeVolumes`, and `ec2:DeleteVolume` permissions to manage it.

Attach, detach, or inspect the volume with:

```bash
./aws/ebs-t3-micro.sh status
./aws/ebs-t3-micro.sh attach
./aws/ebs-t3-micro.sh detach
```

`attach` uses `/dev/sdf` by default; supply a different device name as its second argument if needed. The IAM principal also needs `ec2:AttachVolume` and `ec2:DetachVolume`. On Nitro instances, the guest operating system can expose the attached device under an NVMe name rather than `/dev/sdf`.

## G6 Spot instance

The `g6.xlarge` one-time Spot instance is disabled by default. Create it explicitly with:

```bash
terraform -chdir=aws apply -var='create_g6_spot_instance=true'
```

It uses the current official Ubuntu 24.04 LTS AMI. Spot capacity is not guaranteed, and AWS can interrupt and terminate the instance. A normal `terraform apply` does not create it.

```bash
./aws/ec2-g6-xlarge.sh status
./aws/ec2-g6-xlarge.sh stop
./aws/ec2-g6-xlarge.sh start
./aws/ec2-g6-xlarge.sh terminate
```

`terminate` permanently deletes the G6 Spot instance. Its IAM principal needs `ec2:TerminateInstances`.
