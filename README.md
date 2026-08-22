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
docker build --target server -t local-llm:server .
```

## Run Docker containers

> To setup a Cloudflare tunnel and retrieve a token, follow the instruction [here](https://developers.cloudflare.com/tunnel/setup/). This is for running a public server.

### Serve mode (local-llm:serve) - Local coding agents

```bash
docker run -itd --gpus all -p 9931:9931 \
    -v ./models:/models --name local-llm-serve local-llm:serve \
    -m /models/Qwen3.5-9B-Q4_K_M.gguf --host 0.0.0.0 --port 9931 \
    -ngl all --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.0 \
    --presence-penalty 0.0 --repeat-penalty 1.0 \
    -c 108000 -ctk q8_0 -ctv q8_0 --flash-attn
```

**Parameters:**
- `-m`: Model path (`/models/Qwen3.5-9B-Q4_K_M.gguf`)
- `--host 0.0.0.0 --port 9931`: Bind to all interfaces on port 9931
- `-ngl all`: Offload all layers to GPU
- `--temp 0.6`: Temperature for randomness (lower = more deterministic)
- `--top-p 0.95` + `--top-k 20`: Nucleus sampling parameters
- `--min-p 0.0`: Minimum probability threshold
- `--presence-penalty 0.0`: Penalize repeated topics
- `--repeat-penalty 1.0`: Penalize repeated tokens
- `-c 108000`: Context size (108K tokens)
- `-ctk q8_0 -ctv q8_0`: KV cache type for K and V (q8_0 saves VRAM)
- `--flash-attn`: Enable flash attention for faster inference

**Use case:** Local coding agents like opencode

### Server mode (local-llm:server) - Chat mode with web UI

```bash
docker run -itd --gpus all -p 9931:9931 \
    -v ./models:/models -e TUNNEL_TOKEN=<token> \
    --restart unless-stopped \
    --name local-llm-server local-llm:server
```

**Parameters:**
- `-e TUNNEL_TOKEN`: Cloudflare Tunnel authentication token
- `--restart unless-stopped`: Auto-restart on failure

**Access:**
- Chat UI: http://localhost:9931
- API: http://localhost:9931/v1/chat/completions

> Configs and docs are now for Qwen3.5 9B and following [Qwen's recommendations](https://huggingface.co/Qwen/Qwen3.5-9B#using-qwen35-via-the-chat-completions-api).
