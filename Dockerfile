FROM nvidia/cuda:13.3.1-devel-ubuntu24.04 AS build

# Install deps
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    ca-certificates \
    curl

# Clone llama.cpp
RUN git clone https://github.com/ggml-org/llama.cpp.git app

WORKDIR /app

# Install cloudflared
RUN curl -Lo cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod +x cloudflared

# Build with CUDA
RUN cmake -B build \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES=120 \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    . && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir lib && \
    find build -name "*.so*" -exec cp -P {} lib \;

FROM nvidia/cuda:13.3.1-runtime-ubuntu24.04 AS server

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libgomp1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/cloudflared /usr/local/bin/cloudflared
COPY --from=build /app/lib/ /app
COPY --from=build /app/build/bin/llama /app/build/bin/llama-server /app

WORKDIR /app

# Entrypoint
COPY start.sh start.sh
RUN chmod +x start.sh

EXPOSE 8080

CMD ["./start.sh"]
