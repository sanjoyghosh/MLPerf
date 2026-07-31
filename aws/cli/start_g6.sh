#!/usr/bin/env bash
set -euo pipefail

aws --profile default --region us-west-2 ec2 start-instances \
  --instance-ids i-05364ed42bd699a03

aws --profile default --region us-west-2 ec2 wait instance-running \
  --instance-ids i-05364ed42bd699a03

ssh-keygen -R 44.228.245.25
ssh -i ~/.ssh/id_ed25519 ubuntu@44.228.245.25
