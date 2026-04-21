#!/usr/bin/env bash
# Build all riscv64 container images for Kubernetes
#
# Usage:
#   ./riscv64/scripts/build-images.sh [REGISTRY]
#
# Environment variables:
#   REGISTRY            Container registry (default: ghcr.io/riseproject-dev)
#   K8S_VERSION         Kubernetes version tag (default: from git)
#   GO_VERSION          Go version (default: from .go-version)
#   ETCD_VERSION        etcd version (default: v3.5.21)
#   COREDNS_VERSION     CoreDNS version (default: v1.12.1)
#   FLANNEL_VERSION     Flannel version (default: v0.28.0)
#   PAUSE_TAG           Pause image tag (default: 3.10.2)

set -euo pipefail

KUBE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "${KUBE_ROOT}"

REGISTRY="${1:-${REGISTRY:-ghcr.io/riseproject-dev}}"
GO_VERSION="${GO_VERSION:-$(cat .go-version)}"
K8S_VERSION="${K8S_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")}"
ETCD_VERSION="${ETCD_VERSION:-v3.5.21}"
COREDNS_VERSION="${COREDNS_VERSION:-v1.12.1}"
FLANNEL_VERSION="${FLANNEL_VERSION:-v0.28.0}"
PAUSE_TAG="${PAUSE_TAG:-3.10.2}"
PLATFORM="linux/riscv64"

GO_RUNNER_TAG="v2.4.0-go${GO_VERSION}-trixie.0"
IPTABLES_TAG="v0.9.0-trixie.0"
SETCAP_TAG="trixie-v1.0.0"

echo "=== Building riscv64 images ==="
echo "Registry:  ${REGISTRY}"
echo "K8s:       ${K8S_VERSION}"
echo "Go:        ${GO_VERSION}"
echo "Platform:  ${PLATFORM}"
echo ""

# Ensure buildx is available
docker buildx inspect riscv64-builder >/dev/null 2>&1 || \
  docker buildx create --name riscv64-builder --use

# 1. go-runner (dependency for other images)
echo "--- Building go-runner ---"
docker buildx build --platform "${PLATFORM}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  -t "${REGISTRY}/go-runner:${GO_RUNNER_TAG}" \
  --load \
  riscv64/images/go-runner/

# 2. setcap
echo "--- Building setcap ---"
docker buildx build --platform "${PLATFORM}" \
  -t "${REGISTRY}/setcap:${SETCAP_TAG}" \
  --load \
  riscv64/images/setcap/

# 3. distroless-iptables (depends on go-runner)
echo "--- Building distroless-iptables ---"
docker buildx build --platform "${PLATFORM}" \
  --build-arg GORUNNERIMAGE="${REGISTRY}/go-runner:${GO_RUNNER_TAG}" \
  -t "${REGISTRY}/distroless-iptables:${IPTABLES_TAG}" \
  --load \
  riscv64/images/distroless-iptables/

# 4. Ecosystem: etcd
echo "--- Building etcd ---"
docker buildx build --platform "${PLATFORM}" \
  --build-arg ETCD_VERSION="${ETCD_VERSION}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  -t "${REGISTRY}/etcd:${ETCD_VERSION}-riscv64" \
  --load \
  riscv64/ecosystem/etcd/

# 5. Ecosystem: CoreDNS
echo "--- Building CoreDNS ---"
docker buildx build --platform "${PLATFORM}" \
  --build-arg COREDNS_VERSION="${COREDNS_VERSION}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  -t "${REGISTRY}/coredns:${COREDNS_VERSION}-riscv64" \
  --load \
  riscv64/ecosystem/coredns/

# 6. Ecosystem: Flannel
echo "--- Building Flannel ---"
docker buildx build --platform "${PLATFORM}" \
  --build-arg FLANNEL_VERSION="${FLANNEL_VERSION}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  -t "${REGISTRY}/flannel:${FLANNEL_VERSION}-riscv64" \
  --load \
  riscv64/ecosystem/flannel/

echo ""
echo "=== All images built ==="
echo ""
echo "To build Kubernetes component images, first build binaries:"
echo "  ./riscv64/scripts/build-binaries.sh"
echo ""
echo "Then build component images with:"
echo "  KUBE_DOCKER_REGISTRY=${REGISTRY} \\"
echo "  KUBE_GORUNNER_IMAGE=${REGISTRY}/go-runner:${GO_RUNNER_TAG} \\"
echo "  KUBE_PROXY_BASE_IMAGE=${REGISTRY}/distroless-iptables:${IPTABLES_TAG} \\"
echo "  KUBE_BUILD_SETCAP_IMAGE=${REGISTRY}/setcap:${SETCAP_TAG} \\"
echo "  KUBE_BUILD_PLATFORMS=linux/riscv64 \\"
echo "  make release-images"
