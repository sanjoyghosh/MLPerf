#!/usr/bin/env bash
# Start the G6 and run the MLPerf Llama 3.1 8B Offline benchmark with vLLM.
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-west-2}"
G6_INSTANCE_ID="${G6_INSTANCE_ID:-i-05364ed42bd699a03}"
G6_HOST="${G6_HOST:-44.228.245.25}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

# These are paths on the G6 EBS volume, not paths on this computer.
ROOT="${ROOT:-/mnt/ebs/Inference/Llama-3.1-8B}"
MODEL_PATH="${MODEL_PATH:-$ROOT/model}"
DATASET_PATH="${DATASET_PATH:-$ROOT/dataset/cnn_eval.json}"
BATCH_SIZE="${BATCH_SIZE:-4}"
TOTAL_SAMPLE_COUNT="${TOTAL_SAMPLE_COUNT:-13368}"
VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-4096}"

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
  --instance-ids "$G6_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)"

case "$INSTANCE_STATE" in
  stopped)
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 start-instances \
      --instance-ids "$G6_INSTANCE_ID" >/dev/null
    ;;
  pending|running)
    ;;
  *)
    echo "G6 instance is $INSTANCE_STATE; start it manually before running the benchmark." >&2
    exit 1
    ;;
esac

aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ec2 wait instance-running \
  --instance-ids "$G6_INSTANCE_ID"

# The Elastic IP can be reused by a replacement instance.
ssh-keygen -R "$G6_HOST" >/dev/null 2>&1 || true

ssh -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  "ubuntu@$G6_HOST" \
  "ROOT=$(printf '%q' "$ROOT") MODEL_PATH=$(printf '%q' "$MODEL_PATH") DATASET_PATH=$(printf '%q' "$DATASET_PATH") BATCH_SIZE=$(printf '%q' "$BATCH_SIZE") TOTAL_SAMPLE_COUNT=$(printf '%q' "$TOTAL_SAMPLE_COUNT") VLLM_MAX_MODEL_LEN=$(printf '%q' "$VLLM_MAX_MODEL_LEN") bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

if [[ -f "$ROOT/inference/language/llama3.1-8b/main.py" ]]; then
  REPO="$ROOT/inference"
else
  REPO="$ROOT/src/inference"
fi
LLAMA_DIR="$REPO/language/llama3.1-8b"
VENV="$ROOT/venv"
OUTPUT_LOG_DIR="$ROOT/logs/offline-performance-$(date +%Y%m%d-%H%M%S)"

command -v nvidia-smi >/dev/null 2>&1 || {
  echo "NVIDIA driver tools are not installed or not in PATH." >&2
  exit 1
}
nvidia-smi

[[ -x "$VENV/bin/python" ]] || {
  echo "Python environment not found: $VENV" >&2
  echo "Create the vLLM environment on EBS before running this script." >&2
  exit 1
}
[[ -f "$LLAMA_DIR/main.py" ]] || {
  echo "MLPerf checkout not found: $LLAMA_DIR" >&2
  exit 1
}
[[ -f "$MODEL_PATH/config.json" ]] || {
  echo "Llama model config not found: $MODEL_PATH/config.json" >&2
  echo "Set MODEL_PATH to the directory containing the model config.json." >&2
  exit 1
}
[[ -f "$DATASET_PATH" ]] || {
  echo "MLPerf dataset not found: $DATASET_PATH" >&2
  echo "Set DATASET_PATH to cnn_eval.json." >&2
  exit 1
}
[[ "$BATCH_SIZE" =~ ^[1-9][0-9]*$ ]] || {
  echo "BATCH_SIZE must be a positive integer." >&2
  exit 2
}
[[ "$TOTAL_SAMPLE_COUNT" =~ ^[1-9][0-9]*$ ]] || {
  echo "TOTAL_SAMPLE_COUNT must be a positive integer." >&2
  exit 2
}
[[ "$VLLM_MAX_MODEL_LEN" =~ ^[1-9][0-9]*$ ]] || {
  echo "VLLM_MAX_MODEL_LEN must be a positive integer." >&2
  exit 2
}

export PIP_CACHE_DIR="$ROOT/cache/pip"
export XDG_CACHE_HOME="$ROOT/cache"
export HF_HOME="$ROOT/cache/huggingface"
mkdir -p "$OUTPUT_LOG_DIR" "$PIP_CACHE_DIR" "$XDG_CACHE_HOME" "$HF_HOME"

cd "$LLAMA_DIR"
"$VENV/bin/python" -u main.py \
  --scenario Offline \
  --model-path "$MODEL_PATH" \
  --batch-size "$BATCH_SIZE" \
  --dtype bfloat16 \
  --user-conf user.conf \
  --total-sample-count "$TOTAL_SAMPLE_COUNT" \
  --dataset-path "$DATASET_PATH" \
  --output-log-dir "$OUTPUT_LOG_DIR" \
  --tensor-parallel-size 1 \
  --vllm

echo
echo "Benchmark logs: $OUTPUT_LOG_DIR"
REMOTE_SCRIPT
