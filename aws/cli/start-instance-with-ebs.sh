#!/usr/bin/env bash
# Start an instance and make the standalone data EBS volume available safely.
# Required environment variables: INSTANCE_LABEL, INSTANCE_ID, INSTANCE_HOST,
# and EBS_VOLUME_ID. This script never creates or formats a filesystem.
set -euo pipefail

: "${INSTANCE_LABEL:?INSTANCE_LABEL is required}"
: "${INSTANCE_ID:?INSTANCE_ID is required}"
: "${INSTANCE_HOST:?INSTANCE_HOST is required}"
: "${EBS_VOLUME_ID:?EBS_VOLUME_ID is required}"

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-west-2}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/ebs}"
EBS_DEVICE_NAME="${EBS_DEVICE_NAME:-/dev/sdf}"

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

INSTANCE_STATE="$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)"

case "$INSTANCE_STATE" in
  stopped)
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 start-instances \
      --instance-ids "$INSTANCE_ID" >/dev/null
    ;;
  pending|running)
    ;;
  *)
    echo "$INSTANCE_LABEL instance is $INSTANCE_STATE; start it manually before continuing." >&2
    exit 1
    ;;
esac

aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID"
aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait instance-status-ok \
  --instance-ids "$INSTANCE_ID"

ATTACHMENT_INSTANCE_ID="$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 describe-volumes \
  --volume-ids "$EBS_VOLUME_ID" \
  --query 'Volumes[0].Attachments[0].InstanceId' \
  --output text)"

case "$ATTACHMENT_INSTANCE_ID" in
  None)
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 attach-volume \
      --volume-id "$EBS_VOLUME_ID" \
      --instance-id "$INSTANCE_ID" \
      --device "$EBS_DEVICE_NAME" >/dev/null
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait volume-in-use \
      --volume-ids "$EBS_VOLUME_ID"
    ;;
  "$INSTANCE_ID")
    ;;
  *)
    echo "Detaching EBS volume $EBS_VOLUME_ID from $ATTACHMENT_INSTANCE_ID."
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 detach-volume \
      --volume-id "$EBS_VOLUME_ID" \
      --instance-id "$ATTACHMENT_INSTANCE_ID" >/dev/null
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait volume-available \
      --volume-ids "$EBS_VOLUME_ID"
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 attach-volume \
      --volume-id "$EBS_VOLUME_ID" \
      --instance-id "$INSTANCE_ID" \
      --device "$EBS_DEVICE_NAME" >/dev/null
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait volume-in-use \
      --volume-ids "$EBS_VOLUME_ID"
    ;;
esac

# Nitro exposes an EBS attachment as an NVMe device; its serial is the volume ID
# without hyphens, e.g. vol-0123... becomes vol0123....
VOLUME_SERIAL="${EBS_VOLUME_ID//-/}"
ssh-keygen -R "$INSTANCE_HOST" >/dev/null 2>&1 || true

ssh -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  "ubuntu@$INSTANCE_HOST" \
  "VOLUME_SERIAL=$(printf '%q' "$VOLUME_SERIAL") MOUNT_POINT=$(printf '%q' "$MOUNT_POINT") bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

for _ in $(seq 1 12); do
  DEVICE_NAME="$(lsblk -dn -o NAME,SERIAL | awk -v serial="$VOLUME_SERIAL" '$2 == serial { print $1; exit }')"
  [[ -n "$DEVICE_NAME" ]] && break
  sleep 5
done

[[ -n "${DEVICE_NAME:-}" ]] || {
  echo "Could not find the attached EBS device with serial $VOLUME_SERIAL." >&2
  exit 1
}
DEVICE="/dev/$DEVICE_NAME"

if mountpoint -q "$MOUNT_POINT"; then
  CURRENT_SOURCE="$(findmnt -no SOURCE --target "$MOUNT_POINT")"
  if [[ "$(readlink -f "$CURRENT_SOURCE")" == "$(readlink -f "$DEVICE")" ]]; then
    echo "$DEVICE is already mounted at $MOUNT_POINT."
    exit 0
  fi
  echo "$MOUNT_POINT is mounted from $CURRENT_SOURCE; refusing to replace it." >&2
  exit 1
fi

if findmnt -rn --source "$DEVICE" >/dev/null; then
  echo "$DEVICE is already mounted elsewhere; refusing to remount it." >&2
  findmnt --source "$DEVICE"
  exit 1
fi

FSTYPE="$(sudo blkid -s TYPE -o value "$DEVICE" 2>/dev/null || true)"
[[ -n "$FSTYPE" ]] || {
  echo "No filesystem found on $DEVICE; refusing to format it." >&2
  exit 1
}
UUID="$(sudo blkid -s UUID -o value "$DEVICE")"

sudo mkdir -p "$MOUNT_POINT"
sudo mount -t "$FSTYPE" "$DEVICE" "$MOUNT_POINT"
sudo cp /etc/fstab /etc/fstab.before-start-instance-with-ebs
sudo sed -i "\\|[[:space:]]$MOUNT_POINT[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s defaults,nofail 0 2\n' "$UUID" "$MOUNT_POINT" "$FSTYPE" | sudo tee -a /etc/fstab >/dev/null

findmnt -no SOURCE,FSTYPE,TARGET "$MOUNT_POINT"
ls -lah "$MOUNT_POINT"
REMOTE_SCRIPT
