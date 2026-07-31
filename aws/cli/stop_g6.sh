#!/usr/bin/env bash
set -euo pipefail

aws --profile default --region us-west-2 ec2 stop-instances \
  --instance-ids i-05364ed42bd699a03

aws --profile default --region us-west-2 ec2 wait instance-stopped \
  --instance-ids i-05364ed42bd699a03
