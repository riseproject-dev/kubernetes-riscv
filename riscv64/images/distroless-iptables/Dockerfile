# distroless-iptables for linux/riscv64 on Debian Trixie
#
# This is a community-maintained riscv64 variant of the upstream
# distroless-iptables image (kubernetes/release images/build/distroless-iptables/).
# It provides the base image for kube-proxy with iptables, ipset, conntrack,
# and nftables support.
#
# Build:
#   docker buildx build --platform linux/riscv64 \
#     --build-arg GORUNNERIMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0 \
#     -t ghcr.io/riseproject-dev/distroless-iptables:v0.9.0-trixie.0 .
#
# This follows the upstream trixie variant pattern, staging binaries and their
# library dependencies from a Debian Trixie build layer into a distroless base.

ARG BASEIMAGE=debian:trixie-slim
ARG DISTROLESS_IMAGE=gcr.io/distroless/static-debian13:nonroot
ARG GORUNNERIMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0

FROM ${GORUNNERIMAGE} AS go-runner-src

# Stage 1: Install packages and collect binaries + dependencies
FROM ${BASEIMAGE} AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables \
    nftables \
    ipset \
    kmod \
    conntrack \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Stage binaries and their shared library dependencies into /stage
RUN mkdir -p /stage/usr/sbin /stage/usr/bin /stage/usr/lib /stage/etc

# Copy iptables/nftables binaries and dependencies
RUN for bin in \
      /usr/sbin/iptables /usr/sbin/iptables-save /usr/sbin/iptables-restore \
      /usr/sbin/ip6tables /usr/sbin/ip6tables-save /usr/sbin/ip6tables-restore \
      /usr/sbin/iptables-nft /usr/sbin/iptables-nft-save /usr/sbin/iptables-nft-restore \
      /usr/sbin/ip6tables-nft /usr/sbin/ip6tables-nft-save /usr/sbin/ip6tables-nft-restore \
      /usr/sbin/xtables-nft-multi \
      /usr/sbin/nft \
      /usr/sbin/ipset \
      /usr/sbin/modprobe /usr/sbin/insmod \
      /usr/sbin/conntrack \
      /usr/bin/wc /usr/bin/cat; do \
    if [ -f "$bin" ] || [ -L "$bin" ]; then \
      cp -a "$bin" "/stage$(dirname $bin)/" 2>/dev/null || true; \
      ldd "$bin" 2>/dev/null | grep -o '/[^ ]*' | sed 's|^/lib/|/usr/lib/|;s|^/sbin/|/usr/sbin/|' | while read lib; do \
        dir=$(dirname "$lib"); \
        mkdir -p "/stage$dir"; \
        cp -aL "$lib" "/stage$lib" 2>/dev/null || true; \
      done; \
    fi; \
  done

# Copy helper shell utilities (use /usr/bin paths — /bin is a symlink in Trixie)
RUN for bin in /usr/bin/dash /usr/bin/sh /usr/bin/chmod /usr/bin/grep /usr/bin/ln /usr/bin/rm /usr/bin/sleep; do \
    if [ -f "$bin" ] || [ -L "$bin" ]; then \
      mkdir -p "/stage$(dirname $bin)/"; \
      cp -aL "$bin" "/stage$bin" 2>/dev/null || true; \
      ldd "$bin" 2>/dev/null | grep -o '/[^ ]*' | sed 's|^/lib/|/usr/lib/|' | while read lib; do \
        dir=$(dirname "$lib"); \
        mkdir -p "/stage$dir"; \
        cp -aL "$lib" "/stage$lib" 2>/dev/null || true; \
      done; \
    fi; \
  done

# Copy ld-linux for riscv64 dynamic linking (use /usr/lib — /lib is a symlink in Trixie)
RUN mkdir -p /stage/usr/lib/riscv64-linux-gnu && \
    cp -aL /usr/lib/riscv64-linux-gnu/ld-linux-riscv64-lp64d.so* /stage/usr/lib/riscv64-linux-gnu/ 2>/dev/null || true

# Stage 2: Build final image
FROM ${DISTROLESS_IMAGE}

COPY --from=builder /stage/ /
COPY --from=go-runner-src /usr/local/bin/go-runner /usr/local/bin/go-runner

ENTRYPOINT ["/usr/local/bin/go-runner"]
