#!/usr/bin/env bash
# Format (when necessary) and mount an already-attached EBS block device.
set -euo pipefail

DEVICE="${1:-}"
MOUNT_POINT="${2:-/mnt/ebs}"
FILESYSTEM="${FILESYSTEM:-ext4}"

usage() {
  echo "Usage: sudo $(basename "$0") <device> [mount-point]" >&2
  echo "Example: sudo $(basename "$0") /dev/nvme1n1 /mnt/ebs" >&2
  exit 2
}

[[ -n "$DEVICE" ]] || usage
[[ $EUID -eq 0 ]] || {
  echo "Run this script with sudo." >&2
  exit 1
}
[[ -b "$DEVICE" ]] || {
  echo "Not a block device: $DEVICE" >&2
  exit 1
}
[[ "$FILESYSTEM" == "ext4" ]] || {
  echo "Only ext4 is supported (set FILESYSTEM=ext4 or omit it)." >&2
  exit 2
}

for command in blkid findmnt lsblk mkfs.ext4 mount mkdir; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

# Do not format or remount a device that is already in use elsewhere.
if findmnt --source "$DEVICE" --noheadings >/dev/null 2>&1; then
  echo "$DEVICE is already mounted; refusing to change it." >&2
  findmnt --source "$DEVICE"
  exit 1
fi

CURRENT_SOURCE="$(findmnt --target "$MOUNT_POINT" --noheadings --output SOURCE 2>/dev/null || true)"
if [[ -n "$CURRENT_SOURCE" ]]; then
  if [[ "$(readlink -f "$CURRENT_SOURCE")" == "$(readlink -f "$DEVICE")" ]]; then
    echo "$DEVICE is already mounted at $MOUNT_POINT."
    exit 0
  fi
  echo "$MOUNT_POINT is already mounted from $CURRENT_SOURCE; refusing to change it." >&2
  exit 1
fi

FSTYPE="$(blkid --output value --match-tag TYPE "$DEVICE" 2>/dev/null || true)"
if [[ -z "$FSTYPE" ]]; then
  echo "No filesystem found on $DEVICE; formatting it as $FILESYSTEM."
  mkfs.ext4 -F "$DEVICE"
  FSTYPE="$FILESYSTEM"
else
  echo "Found existing $FSTYPE filesystem on $DEVICE; preserving its contents."
fi

UUID="$(blkid --output value --match-tag UUID "$DEVICE")"
[[ -n "$UUID" ]] || {
  echo "Could not determine UUID for $DEVICE." >&2
  exit 1
}

mkdir -p "$MOUNT_POINT"
mount -t "$FSTYPE" "$DEVICE" "$MOUNT_POINT"

FSTAB_ENTRY="UUID=$UUID $MOUNT_POINT $FSTYPE defaults,nofail 0 2"
if ! grep -Fqx "$FSTAB_ENTRY" /etc/fstab; then
  # Remove an older entry for this volume UUID, then retain all other entries.
  sed -i.bak "\\|^UUID=$UUID[[:space:]]|d" /etc/fstab
  rm -f /etc/fstab.bak
  printf '%s\n' "$FSTAB_ENTRY" >> /etc/fstab
fi

echo "Mounted $DEVICE at $MOUNT_POINT and added its UUID to /etc/fstab."
