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

cmake --build build --config Release -j$(nproc)

./build/bin/llama-quantize <path>/<model>.gguf <path>/<model>-Q8_0.gguf Q8_0

```

## Build Docker images

```bash
docker build --target serve -t local-llm:serve .
docker build --target server -t local-llm:server .
```

## Run Docker containers

> To setup a Cloudflare tunnel and retrieve a token, follow the instruction [here](https://developers.cloudflare.com/tunnel/setup/). This is for running a public server.

```bash
docker run -itd --rm --gpus all -p 8080:8080 \
    -v ./models:/models --name local-llm-serve local-llm:serve \
    -m /models/qwen3.5-4b-Q8_0.gguf --host 0.0.0.0 --port 8080 \
    -ngl all --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.0 \
    --presence-penalty 0.0 --repeat-penalty 1.0 \
    -c 32768 -ctk q8_0 -ctv q8_0

docker run -itd --gpus all -p 8080:8080 \
    -v ./models:/models -e TUNNEL_TOKEN=<token> \
    --restart unless-stopped \
    --name local-llm-server local-llm:server
```

> Configs and docs are now for Qwen3.5 4B and following [Qwen's recommendations](https://huggingface.co/Qwen/Qwen3.5-4B#using-qwen35-via-the-chat-completions-api).
