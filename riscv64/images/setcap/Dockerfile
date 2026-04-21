# setcap image for linux/riscv64 on Debian Trixie
#
# This is a community-maintained riscv64 variant of the upstream setcap
# image (kubernetes/release images/build/setcap/). Used in multi-stage
# builds to apply capabilities (e.g., cap_net_bind_service for kube-apiserver).
#
# Build:
#   docker buildx build --platform linux/riscv64 \
#     -t ghcr.io/riseproject-dev/setcap:trixie-v1.0.0 .

ARG BASEIMAGE=debian:trixie-slim

FROM ${BASEIMAGE}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libcap2 \
       libcap2-bin \
    && rm -rf /var/lib/apt/lists/*
