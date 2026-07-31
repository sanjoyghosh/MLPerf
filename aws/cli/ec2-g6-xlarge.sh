#!/usr/bin/env bash
# Manage the g6.xlarge Spot instance defined by this Terraform configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
ACTION="${1:-}"

usage() {
  echo "Usage: $(basename "$0") {start|stop|terminate|status}" >&2
  exit 2
}

case "$ACTION" in
  start|stop|terminate|status) ;;
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

INSTANCE_ID="$(terraform -chdir="$TERRAFORM_DIR" output -raw g6_spot_instance_id 2>/dev/null)" || {
  echo "Could not read g6_spot_instance_id from Terraform state. Run 'terraform apply' first." >&2
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
  start)
    aws_ec2 start-instances --instance-ids "$INSTANCE_ID" \
      --query 'StartingInstances[0].{InstanceId:InstanceId,PreviousState:PreviousState.Name,CurrentState:CurrentState.Name}' \
      --output table
    ;;
  stop)
    aws_ec2 stop-instances --instance-ids "$INSTANCE_ID" \
      --query 'StoppingInstances[0].{InstanceId:InstanceId,PreviousState:PreviousState.Name,CurrentState:CurrentState.Name}' \
      --output table
    ;;
  terminate)
    aws_ec2 terminate-instances --instance-ids "$INSTANCE_ID" \
      --query 'TerminatingInstances[0].{InstanceId:InstanceId,PreviousState:PreviousState.Name,CurrentState:CurrentState.Name}' \
      --output table
    ;;
  status)
    aws_ec2 describe-instances --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,Market:InstanceLifecycle}' \
      --output table
    ;;
esac
