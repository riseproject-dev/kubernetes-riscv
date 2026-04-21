# go-runner for linux/riscv64 on Debian Trixie
#
# This is a community-maintained riscv64 variant of the upstream go-runner
# image (kubernetes/release images/build/go-runner/). It follows the same
# multi-stage pattern but targets Debian Trixie and distroless-debian13.
#
# Build:
#   docker buildx build --platform linux/riscv64 \
#     --build-arg GO_VERSION=1.26.2 \
#     -t ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0 .
#
# The go-runner binary is a simple log-routing wrapper used as the entrypoint
# for Kubernetes component container images.

ARG GO_VERSION=1.26.2
ARG DISTROLESS_IMAGE=gcr.io/distroless/static-debian13:nonroot

# Stage 1: Build go-runner from source
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-trixie AS builder

ARG TARGETOS=linux
ARG TARGETARCH=riscv64

COPY go.mod go-runner.go /go-runner/
WORKDIR /go-runner

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags '-s -w -buildid= -extldflags "-static"' \
    -o go-runner .

# Stage 2: Final minimal image
FROM ${DISTROLESS_IMAGE}

COPY --from=builder /go-runner/go-runner /usr/local/bin/go-runner

ENTRYPOINT ["/usr/local/bin/go-runner"]
