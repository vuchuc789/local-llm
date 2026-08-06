#!/bin/bash
set -e

MODEL_PATH=${MODEL_PATH:-/models/gemma.gguf}
PORT=${PORT:-8080}

echo "Starting llama.cpp server..."
/app/llama.cpp/build/bin/llama-server \
  -m "$MODEL_PATH" \
  --host 0.0.0.0 \
  --port $PORT \
  -n 512 \
  --n-gpu-layers 1 \
  &
LLAMA_PID=$!

echo "Starting cloudflared tunnel..."
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN &
TUNNEL_PID=$!

# Handle shutdown properly
trap "kill $LLAMA_PID $TUNNEL_PID" SIGINT SIGTERM

wait -n
