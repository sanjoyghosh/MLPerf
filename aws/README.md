# EC2 instance commands

Run these commands from the repository root after `terraform -chdir=aws/terraform apply` has created the instance. The Terraform configuration, local state, and variable file are in `aws/terraform/`.

```bash
./aws/cli/ec2-t3-large.sh status
./aws/cli/ec2-t3-large.sh stop
./aws/cli/ec2-t3-large.sh start
./aws/cli/ec2-t3-large.sh terminate
```

To start the T3 and mount the standalone data EBS volume when it is unattached:

```bash
./aws/cli/start_t3.sh
```

If the EBS volume is attached to another instance, the script performs a normal detach, waits for it to become available, then attaches it to the T3. Stop workloads using that volume first; the script intentionally does not force-detach it.

The script reads the instance ID, AWS profile, and region from the Terraform configuration and state. The IAM principal also needs `ec2:StartInstances`, `ec2:StopInstances`, `ec2:TerminateInstances`, and `ec2:DescribeInstances` permissions. `terminate` permanently deletes the instance.

Terraform protects managed EC2 instances, the standalone EBS volume, and managed Elastic IP resources with `prevent_destroy`. If a configuration change would replace or delete one of them, Terraform fails before making the change. To intentionally replace or destroy a protected resource, first remove its `prevent_destroy` lifecycle setting in Terraform, apply the intended change, then restore the guard.

## SSH key import

Import the local `~/.ssh/id_ed25519.pub` key as `sanjoy-ed25519` in `us-west-2`:

```bash
./aws/cli/setup-vm.sh
```

Optionally provide a different EC2 key-pair name and public-key path:

```bash
./aws/cli/setup-vm.sh my-key ~/.ssh/another-key.pub
```

## SSH access

The `t3.large` uses a dedicated Terraform-managed security group. Set `ssh_allowed_cidr` in `aws/terraform/terraform.tfvars` to your current public IPv4 address with a `/32` suffix, then run `terraform -chdir=aws/terraform apply`:

```bash
curl -4 https://checkip.global.api.aws/
# Example aws/terraform/terraform.tfvars value: ssh_allowed_cidr = "198.51.100.42/32"
```

The IAM principal needs `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:AuthorizeSecurityGroupEgress`, and `ec2:DeleteSecurityGroup` permissions.

The `t3.large` is configured to use the `sanjoy-ed25519` EC2 key pair. Adding or changing an EC2 key pair requires Terraform to replace an existing instance. Detach the standalone EBS volume before applying this change if it is attached.

## Stable SSH address

Terraform allocates an Elastic IP for the `t3.large`, preserving its public address across stop/start cycles. After applying, retrieve it and use it as `HostName` in `~/.ssh/config`:

```bash
terraform -chdir=aws/terraform output -raw t3_large_elastic_ip
```

The IAM principal needs `ec2:AllocateAddress`, `ec2:AssociateAddress`, `ec2:DisassociateAddress`, `ec2:ReleaseAddress`, and `ec2:DescribeAddresses` permissions.

## Automatic idle stop

Terraform creates CloudWatch alarms that stop the `t3.large` after six consecutive five-minute periods with average CPU utilization at or below 5% (30 minutes total), and the enabled G6 after three such periods (15 minutes total). This is CPU-based inactivity: an active download or benchmark keeps the instance running, but an idle SSH session does not. Change `idle_cpu_threshold_percent` in `aws/terraform/terraform.tfvars` if needed.

Creating the alarms requires `cloudwatch:PutMetricAlarm`, `cloudwatch:DescribeAlarms`, `cloudwatch:ListTagsForResource`, and `cloudwatch:DeleteAlarms`. AWS also requires the `AWSServiceRoleForCloudWatchEvents` service-linked role for CloudWatch EC2 stop actions; creating it requires `iam:CreateServiceLinkedRole` if it does not already exist.

## EBS volume

`terraform -chdir=aws/terraform apply` also creates a standalone 80 GiB `gp3` EBS volume in the same Availability Zone as the EC2 instance. It is not attached to the instance. The IAM principal needs `ec2:CreateVolume`, `ec2:DescribeVolumes`, and `ec2:DeleteVolume` permissions to manage it.

Attach, detach, or inspect the volume with:

```bash
./aws/cli/ebs-t3-large.sh status
./aws/cli/ebs-t3-large.sh attach
./aws/cli/ebs-t3-large.sh detach
```

`attach` uses `/dev/sdf` by default; supply a different device name as its second argument if needed. The IAM principal also needs `ec2:AttachVolume` and `ec2:DetachVolume`. On Nitro instances, the guest operating system can expose the attached device under an NVMe name rather than `/dev/sdf`.

After connecting to the instance and confirming the guest device name with `lsblk`, format it only if needed, mount it, and add a UUID-based `/etc/fstab` entry:

```bash
sudo ./aws/cli/attach-ebs.sh /dev/nvme1n1 /mnt/ebs
```

The script preserves an existing filesystem and its data. It formats a device that has no filesystem as `ext4`; pass the actual NVMe device name shown by `lsblk`.

## G6 Spot instance

The persistent `g6.xlarge` Spot instance is disabled by default. Create it explicitly with:

```bash
terraform -chdir=aws/terraform apply -var='create_g6_spot_instance=true'
```

Both instances use the shared `subnet_id` variable, which keeps them in the same Availability Zone as the standalone EBS volume. Change that subnet only when deliberately moving the whole setup to another Availability Zone.

It uses the current official Ubuntu 24.04 LTS AMI. Spot capacity is not guaranteed; an interruption stops the instance and its persistent request remains active. A normal `terraform -chdir=aws/terraform apply` does not create it.

Terraform reserves a dedicated Elastic IP even while the G6 instance is disabled, then associates it when the G6 instance is created. Retrieve it with:

```bash
terraform -chdir=aws/terraform output -raw g6_elastic_ip
```

The reserved but unassociated Elastic IP incurs AWS Elastic IP charges.

The G6 uses the same `sanjoy-ed25519` key pair and Terraform-managed SSH security group as the T3 instance. Connect to its `g6_elastic_ip` output as the `ubuntu` user.

```bash
./aws/cli/ec2-g6-xlarge.sh status
./aws/cli/ec2-g6-xlarge.sh stop
./aws/cli/ec2-g6-xlarge.sh start
./aws/cli/ec2-g6-xlarge.sh terminate
```

`terminate` permanently deletes the G6 Spot instance. Its IAM principal needs `ec2:TerminateInstances`.

## Run the Llama 3.1 8B vLLM benchmark

After the model, dataset, MLPerf checkout, and Python environment have been prepared on `/mnt/ebs/Inference/Llama-3.1-8B`, run the Offline benchmark from the local machine:

```bash
./aws/cli/run_Llama_3_1_8B.sh
```

It starts the stopped G6, waits for it, refreshes the SSH host key for its Elastic IP, and runs the benchmark remotely. Set `MODEL_PATH`, `DATASET_PATH`, or `BATCH_SIZE` before running it to override the EBS defaults.
