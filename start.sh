#!/bin/bash
set -e

MODEL_PATH=${MODEL_PATH:-/models/qwen3.5-4b-Q8_0.gguf}
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
  --temperature 1.0 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --ctx-size 32768 \
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
