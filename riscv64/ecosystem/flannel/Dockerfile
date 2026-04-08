# Flannel for linux/riscv64 on Debian Trixie
#
# Flannel is a simple overlay network for Kubernetes. It compiles from
# source for riscv64 with no modifications.
#
# Build:
#   docker buildx build --platform linux/riscv64 \
#     --build-arg FLANNEL_VERSION=v0.28.0 \
#     -t ghcr.io/riseproject-dev/flannel:v0.28.0-riscv64 .

ARG GO_VERSION=1.26.2
ARG BASEIMAGE=debian:trixie-slim

# Stage 1: Build Flannel from source
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS builder

ARG FLANNEL_VERSION=v0.28.0
ARG TARGETOS=linux
ARG TARGETARCH=riscv64

RUN git clone --depth 1 --branch ${FLANNEL_VERSION} \
    https://github.com/flannel-io/flannel.git /flannel

WORKDIR /flannel

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w -X github.com/flannel-io/flannel/pkg/version.Version=${FLANNEL_VERSION}" \
    -o /out/flanneld .

# Build flannel-cni-plugin
RUN git clone --depth 1 \
    https://github.com/flannel-io/cni-plugin.git /flannel-cni

WORKDIR /flannel-cni

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w" \
    -o /out/flannel-cni .

# Stage 2: Final image
FROM ${BASEIMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables \
    iproute2 \
    net-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/flanneld /opt/bin/flanneld
COPY --from=builder /out/flannel-cni /opt/cni/bin/flannel

ENTRYPOINT ["/opt/bin/flanneld"]
