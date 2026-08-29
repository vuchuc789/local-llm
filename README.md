## Convert from huggingface models to gguf and quantization

```bash
git clone https://github.com/ggml-org/llama.cpp.git

cd llama.cpp

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python convert_hf_to_gguf.py ~/.cache/huggingface/hub/<model>/snapshots/<XXXXXXXX> --outfile <path>/<model>.gguf

cmake -B build \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES=120 \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined

# CUDA 12.0 (sm_120) supports: RTX 5060, RTX 5070, RTX 5080, RTX 5090
# See: https://developer.nvidia.com/cuda/gpus

cmake --build build --config Release -j$(nproc)

./build/bin/llama-quantize <path>/<model>.gguf <path>/<model>-Q4_K_M.gguf Q4_K_M

```

## Build Docker images

```bash
docker build --target serve -t local-llm:serve .
# docker build --target server -t local-llm:server . (deprecated)
```

## Run using Docker Compose

> To setup a Cloudflare tunnel and retrieve a token, follow the instruction [here](https://developers.cloudflare.com/tunnel/setup/). This is for running a public server.

### Setup

Create a `.env` file or set environment variables:

```bash
# Required
export TUNNEL_TOKEN=<your-cloudflare-tunnel-token>

# Optional (with defaults)
export MODEL=/models/Qwen3.5-9B-Q4_K_M.gguf
export HOST=0.0.0.0
export PORT=9931
export CORS_ORIGINS=localhost
export GPU_LAYERS=all
export FIT=off
export FLASH_ATTN=on
export TEMPERATURE=0.6
export TOP_P=0.95
export TOP_K=20
export MIN_P=0.0
export PRESENCE_PENALTY=0.0
export REPEAT_PENALTY=1.0
export CTX_SIZE=108000
export CACHE_TYPE_K=q8_0
export CACHE_TYPE_V=q8_0
export MMPROJ=/models/mmproj-Qwen3.5-9B-F16.gguf
export MMPROJ_OFFLOAD=off
```

### Start services

```bash
docker-compose up --build
```

### Service details

#### llama-server

Built from `local-llm:serve` image with all llama.cpp server options as environment variables.

**Environment variables:**
- `LLAMA_ARG_MODEL`: Model path (default: `/models/Qwen3.5-9B-Q4_K_M.gguf`)
- `LLAMA_ARG_MMPROJ`: MMProj model path for vision (default: `/models/mmproj-Qwen3.5-9B-F16.gguf`)
- `LLAMA_ARG_HOST`: Host to bind (default: `0.0.0.0`)
- `LLAMA_ARG_PORT`: Port to bind (default: `9931`)
- `LLAMA_ARG_CORS_ORIGINS`: CORS origins (default: `localhost`)
- `LLAMA_ARG_N_GPU_LAYERS`: GPU layers (default: `all`)
- `LLAMA_ARG_FIT`: Fit arguments (default: `off`)
- `LLAMA_ARG_FLASH_ATTN`: Flash attention (default: `on`)
- `LLAMA_ARG_MMPROJ_OFFLOAD`: MMProj offload (default: `off`)
- `LLAMA_ARG_THREADS`: Number of threads (default: `16`)
- `LLAMA_ARG_TEMPERATURE`: Sampling temperature (default: `0.6`)
- `LLAMA_ARG_TOP_P`: Top-p sampling (default: `0.95`)
- `LLAMA_ARG_TOP_K`: Top-k sampling (default: `20`)
- `LLAMA_ARG_MIN_P`: Min-p sampling (default: `0.0`)
- `LLAMA_ARG_PRESENCE_PENALTY`: Presence penalty (default: `0.0`)
- `LLAMA_ARG_REPEAT_PENALTY`: Repeat penalty (default: `1.0`)
- `LLAMA_ARG_CTX_SIZE`: Context size (default: `108000`)
- `LLAMA_ARG_CACHE_TYPE_K`: KV cache type K (default: `q8_0`)
- `LLAMA_ARG_CACHE_TYPE_V`: KV cache type V (default: `q8_0`)

**Access:**
- Local: http://127.0.0.1:9931
- API: http://127.0.0.1:9931/v1/chat/completions

**Use case:** Local coding agents like opencode

#### vision

Supports multimodal models with MMProj for vision capabilities. Enable by setting `LLAMA_ARG_MMPROJ` to a multimodal model path.

#### cloudflared

Uses official prebuilt image `cloudflare/cloudflared:latest`.

**Environment variables:**
- `TUNNEL_TOKEN`: Cloudflare Tunnel authentication token

**Access:**
- External: https://<your-subdomain>.trycloudflare.com
- Chat UI: http://localhost:9931
- API: http://localhost:9931/v1/chat/completions

**Use case:** Public chat mode with web UI

> Configs and docs are now for Qwen3.5 9B and following [Qwen's recommendations](https://huggingface.co/Qwen/Qwen3.5-9B#using-qwen35-via-the-chat-completions-api).
