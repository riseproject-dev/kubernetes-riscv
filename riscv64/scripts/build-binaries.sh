#!/usr/bin/env bash
# Build Kubernetes binaries for linux/riscv64
#
# Usage:
#   ./riscv64/scripts/build-binaries.sh [WHAT]
#
# Examples:
#   ./riscv64/scripts/build-binaries.sh                    # Build all server binaries
#   ./riscv64/scripts/build-binaries.sh "cmd/kubelet"      # Build just kubelet
#
# Environment variables:
#   KUBE_CROSS_IMAGE    Override the kube-cross image
#   KUBE_CROSS_VERSION  Override the kube-cross image tag
#   CGO_ENABLED         Set to 0 to disable CGO (default: 1)

set -euo pipefail

KUBE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "${KUBE_ROOT}"

WHAT="${1:-cmd/kube-apiserver cmd/kube-controller-manager cmd/kube-scheduler cmd/kube-proxy cmd/kubelet cmd/kubeadm cmd/kubectl}"

echo "Building Kubernetes binaries for linux/riscv64..."
echo "Components: ${WHAT}"
echo ""

export KUBE_BUILD_PLATFORMS=linux/riscv64

# Use 'make all' instead of 'make cross' because 'make cross' ignores WHAT
# and builds all server/node/client targets. 'make all' respects WHAT.
#
# KUBE_STATIC_OVERRIDES=kubelet forces kubelet to build without CGO, which
# avoids the need for a full riscv64 glibc sysroot. This disables seccomp
# support. For CGO-enabled kubelet, ensure libc6-dev-riscv64-cross (Debian)
# or equivalent sysroot is installed, then unset KUBE_STATIC_OVERRIDES.
export KUBE_STATIC_OVERRIDES="${KUBE_STATIC_OVERRIDES:-kubelet}"

make all WHAT="${WHAT}"

echo ""
echo "Build complete. Binaries at:"
ls -la _output/local/bin/linux/riscv64/ 2>/dev/null || echo "  (no output found)"
