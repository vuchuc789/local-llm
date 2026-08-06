FROM nvidia/cuda:13.3.1-devel-ubuntu24.04

ARG CUDA_DOCKER_ARCH=default

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_CONTAINER_TOOLKIT_VERSION=1.19.1-1

# Install deps
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install cloudflared
RUN curl -o /usr/local/bin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod +x /usr/local/bin/cloudflared

# Clone llama.cpp
WORKDIR /app
RUN git clone https://github.com/ggml-org/llama.cpp.git

WORKDIR /app/llama.cpp

# Build with CUDA
RUN if [ "${CUDA_DOCKER_ARCH}" != "default" ]; then \
    export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH}"; \
    fi && \
    cmake -B build -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF ${CMAKE_ARGS} -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined . && \
    cmake --build build --config Release -j$(nproc)

# Entrypoint
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
