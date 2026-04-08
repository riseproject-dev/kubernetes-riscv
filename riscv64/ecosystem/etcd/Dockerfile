# etcd for linux/riscv64 on Debian Trixie
#
# etcd does not officially support riscv64, but compiles and runs with
# ETCD_UNSUPPORTED_ARCH=riscv64 set at runtime.
#
# Build:
#   docker buildx build --platform linux/riscv64 \
#     --build-arg ETCD_VERSION=v3.5.21 \
#     -t ghcr.io/riseproject-dev/etcd:v3.5.21-riscv64 .

ARG GO_VERSION=1.26.2
ARG BASEIMAGE=gcr.io/distroless/static-debian13:nonroot

# Stage 1: Build etcd from source
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS builder

ARG ETCD_VERSION=v3.5.21
ARG TARGETOS=linux
ARG TARGETARCH=riscv64

RUN git clone --depth 1 --branch ${ETCD_VERSION} \
    https://github.com/etcd-io/etcd.git /etcd

WORKDIR /etcd

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -o /out/etcd ./server && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -o /out/etcdctl ./etcdctl && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -o /out/etcdutl ./etcdutl

# Stage 2: Final image
FROM ${BASEIMAGE}

COPY --from=builder /out/etcd /usr/local/bin/etcd
COPY --from=builder /out/etcdctl /usr/local/bin/etcdctl
COPY --from=builder /out/etcdutl /usr/local/bin/etcdutl

ENV ETCD_UNSUPPORTED_ARCH=riscv64

EXPOSE 2379 2380

ENTRYPOINT ["/usr/local/bin/etcd"]
