# kube-cross for linux/riscv64 on Debian Trixie
#
# This is a community-maintained riscv64-capable cross-compilation image.
# Unlike the upstream kube-cross (which builds ON amd64/arm64 FOR other arches),
# this image is designed to run natively on riscv64 hardware or to be used
# as a drop-in replacement when cross-compiling FOR riscv64 from amd64.
#
# Usage (native build on riscv64):
#   docker run --rm -v $PWD:/go/src/k8s.io/kubernetes \
#     -w /go/src/k8s.io/kubernetes \
#     ghcr.io/riseproject-dev/kube-cross:v1.36.0-go1.26.2-trixie.0 \
#     make all WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl"
#
# Usage (cross-compile from amd64):
#   docker run --rm -v $PWD:/go/src/k8s.io/kubernetes \
#     -w /go/src/k8s.io/kubernetes \
#     -e KUBE_BUILD_PLATFORMS=linux/riscv64 \
#     ghcr.io/riseproject-dev/kube-cross:v1.36.0-go1.26.2-trixie.0 \
#     make cross WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl"

ARG GO_VERSION=1.26.2
ARG BASEIMAGE=debian:trixie-slim

# Stage 1: Get Go
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-trixie AS go-src

# Stage 2: Build environment
FROM ${BASEIMAGE}

ARG GO_VERSION
ARG TARGETARCH

# Copy Go installation
COPY --from=go-src /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    gnupg2 \
    iproute2 \
    jq \
    kmod \
    make \
    openssh-client \
    patch \
    rsync \
    tar \
    unzip \
    wget \
    # Cross-compilation toolchains for riscv64
    gcc-riscv64-linux-gnu \
    libc6-dev-riscv64-cross \
    && rm -rf /var/lib/apt/lists/*

# Install protobuf compiler (build from source for riscv64)
ARG PROTOBUF_VERSION=23.4
RUN if [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "aarch64" ]; then \
      PROTOC_ARCH=$([ "$(uname -m)" = "x86_64" ] && echo "x86_64" || echo "aarch_64") && \
      curl -fsSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protoc-${PROTOBUF_VERSION}-linux-${PROTOC_ARCH}.zip" \
        -o /tmp/protoc.zip && \
      unzip /tmp/protoc.zip -d /usr/local && \
      rm /tmp/protoc.zip; \
    else \
      apt-get update && apt-get install -y --no-install-recommends protobuf-compiler && \
      rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /go/src/k8s.io/kubernetes
