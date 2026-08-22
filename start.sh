#!/bin/bash
set -e

MODEL_PATH=${MODEL_PATH:-/models/Qwen3.5-9B-Q4_K_M.gguf}
PORT=${PORT:-9931}
GPU_LAYERS=${GPU_LAYERS:-all}
CORS_ORIGINS=${CORS_ORIGINS:-localhost}

echo "Starting llama.cpp server..."
/app/llama-server \
  --model "$MODEL_PATH" \
  --host 0.0.0.0 \
  --port $PORT \
  --cors-origins $CORS_ORIGINS \
  --n-gpu-layers $GPU_LAYERS \
  --fit on \
  --fit-target 256 \
  --flash-attn on \
  --threads 16 \
  --threads-batch 16 \
  --temperature 0.6 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 0.0 \
  --repeat-penalty 1.0 \
  --ctx-size 108000 \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  &
LLAMA_PID=$!

echo "Starting cloudflared tunnel..."
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN &
TUNNEL_PID=$!

# Handle shutdown properly
trap "kill $LLAMA_PID $TUNNEL_PID" SIGINT SIGTERM

wait -n
