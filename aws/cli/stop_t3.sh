#!/usr/bin/env bash
# Stop the T3 after safely releasing the standalone data EBS volume.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export INSTANCE_LABEL="T3"
export INSTANCE_ID="${T3_INSTANCE_ID:-i-09363ec192e7079d4}"
export INSTANCE_HOST="${T3_HOST:-52.11.67.245}"
export EBS_VOLUME_ID="${EBS_VOLUME_ID:-vol-0b51d6632a135056f}"

exec bash "$SCRIPT_DIR/stop-instance-with-ebs.sh"
