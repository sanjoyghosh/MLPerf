#!/usr/bin/env bash
# Import a local ED25519 public key as an EC2 key pair in us-west-2.
set -euo pipefail

KEY_NAME="${1:-sanjoy-ed25519}"
PUBLIC_KEY_PATH="${2:-${HOME}/.ssh/id_ed25519.pub}"
AWS_REGION="us-west-2"

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI is required but was not found in PATH." >&2
  exit 1
}

test -f "$PUBLIC_KEY_PATH" || {
  echo "Public key not found: $PUBLIC_KEY_PATH" >&2
  exit 1
}

aws ec2 import-key-pair \
  --key-name "$KEY_NAME" \
  --public-key-material "fileb://$PUBLIC_KEY_PATH" \
  --region "$AWS_REGION"

echo "Imported EC2 key pair '$KEY_NAME' in $AWS_REGION."
