#!/usr/bin/env bash
# Unmount and detach the standalone data EBS volume, then stop the instance.
# Required environment variables: INSTANCE_LABEL, INSTANCE_ID, INSTANCE_HOST,
# and EBS_VOLUME_ID.
set -euo pipefail

: "${INSTANCE_LABEL:?INSTANCE_LABEL is required}"
: "${INSTANCE_ID:?INSTANCE_ID is required}"
: "${INSTANCE_HOST:?INSTANCE_HOST is required}"
: "${EBS_VOLUME_ID:?EBS_VOLUME_ID is required}"

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-west-2}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/ebs}"

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI is required but was not found in PATH." >&2
  exit 1
}
command -v ssh >/dev/null 2>&1 || {
  echo "ssh is required but was not found in PATH." >&2
  exit 1
}
command -v ssh-keygen >/dev/null 2>&1 || {
  echo "ssh-keygen is required but was not found in PATH." >&2
  exit 1
}
[[ -f "$SSH_KEY" ]] || {
  echo "SSH private key not found: $SSH_KEY" >&2
  exit 1
}

ssh-keygen -R "$INSTANCE_HOST" >/dev/null 2>&1 || true
ssh -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  "ubuntu@$INSTANCE_HOST" \
  "MOUNT_POINT=$(printf '%q' "$MOUNT_POINT") bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

if mountpoint -q "$MOUNT_POINT"; then
  sudo umount "$MOUNT_POINT"
  echo "Unmounted $MOUNT_POINT."
else
  echo "$MOUNT_POINT is not mounted; no unmount needed."
fi
REMOTE_SCRIPT

aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 detach-volume \
  --volume-id "$EBS_VOLUME_ID" \
  --instance-id "$INSTANCE_ID" >/dev/null
aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait volume-available \
  --volume-ids "$EBS_VOLUME_ID"

aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 stop-instances \
  --instance-ids "$INSTANCE_ID" >/dev/null
aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait instance-stopped \
  --instance-ids "$INSTANCE_ID"

echo "$INSTANCE_LABEL instance stopped; EBS volume detached."
