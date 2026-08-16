ARG UBUNTU_VERSION=24.04

ARG CUDA_VERSION=13.3.1
ARG CUDA_ARCH=120

ARG GCC_VERSION=14

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS build

ARG GCC_VERSION
ARG CUDA_ARCH

# Install deps
RUN apt-get update && \
    apt-get install -y \
    gcc-${GCC_VERSION} \
    g++-${GCC_VERSION} \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    git \
    libssl-dev \
    libgomp1

ENV CC=gcc-${GCC_VERSION} CXX=g++-${GCC_VERSION} CUDAHOSTCXX=g++-${GCC_VERSION}

# Clone llama.cpp
RUN git clone https://github.com/ggml-org/llama.cpp.git app

WORKDIR /app

# Build with CUDA
RUN cmake -B build \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    . && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir lib && \
    find build -name "*.so*" -exec cp -P {} lib \;

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION} AS server

ARG TARGETARCH

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libgomp1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install cloudflared
RUN curl -Lo /usr/local/bin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH} \
    && chmod +x /usr/local/bin/cloudflared

COPY --from=build /app/lib/ /app
COPY --from=build /app/build/bin/llama /app/build/bin/llama-server /app

WORKDIR /app

# Entrypoint
COPY start.sh start.sh
RUN chmod +x start.sh

EXPOSE 8080

CMD ["./start.sh"]
