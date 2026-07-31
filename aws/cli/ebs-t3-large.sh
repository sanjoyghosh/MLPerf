#!/usr/bin/env bash
# Attach or detach the standalone EBS volume managed by this Terraform config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
ACTION="${1:-}"
DEVICE_NAME="${2:-/dev/sdf}"

usage() {
  echo "Usage: $(basename "$0") {attach [device-name]|detach|status}" >&2
  exit 2
}

case "$ACTION" in
  attach|detach|status) ;;
  *) usage ;;
esac

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI is required but was not found in PATH." >&2
  exit 1
}

command -v terraform >/dev/null 2>&1 || {
  echo "Terraform is required but was not found in PATH." >&2
  exit 1
}

INSTANCE_ID="$(terraform -chdir="$TERRAFORM_DIR" output -raw instance_id 2>/dev/null)" || {
  echo "Could not read instance_id from Terraform state. Run 'terraform apply' first." >&2
  exit 1
}
VOLUME_ID="$(terraform -chdir="$TERRAFORM_DIR" output -raw ebs_volume_id 2>/dev/null)" || {
  echo "Could not read ebs_volume_id from Terraform state. Run 'terraform apply' first." >&2
  exit 1
}
AWS_PROFILE="$(terraform -chdir="$TERRAFORM_DIR" console -no-color <<<'var.aws_profile' 2>/dev/null | tr -d '\"')" || {
  echo "Could not read aws_profile from Terraform configuration." >&2
  exit 1
}
AWS_REGION="$(terraform -chdir="$TERRAFORM_DIR" console -no-color <<<'var.aws_region' 2>/dev/null | tr -d '\"')" || {
  echo "Could not read aws_region from Terraform configuration." >&2
  exit 1
}

aws_ec2() {
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 "$@"
}

case "$ACTION" in
  attach)
    case "$DEVICE_NAME" in
      /dev/*) ;;
      *)
        echo "Device name must start with /dev/ (for example, /dev/sdf)." >&2
        exit 2
        ;;
    esac
    aws_ec2 attach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID" --device "$DEVICE_NAME" \
      --query '{VolumeId:VolumeId,InstanceId:InstanceId,Device:Device,State:State}' \
      --output table
    ;;
  detach)
    aws_ec2 detach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID" \
      --query '{VolumeId:VolumeId,InstanceId:InstanceId,Device:Device,State:State}' \
      --output table
    ;;
  status)
    aws_ec2 describe-volumes --volume-ids "$VOLUME_ID" \
      --query 'Volumes[0].{VolumeId:VolumeId,State:State,SizeGiB:Size,AvailabilityZone:AvailabilityZone,Attachments:Attachments[*].{InstanceId:InstanceId,Device:Device,State:State}}' \
      --output json
    ;;
esac
