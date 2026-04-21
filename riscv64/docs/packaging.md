# Building and Packaging Kubernetes for riscv64

End-to-end guide for producing a complete set of Kubernetes artifacts for
`linux/riscv64`, suitable for deploying a functional cluster. This covers
every component required by Tier 3 (Community Supported) platform status.

The instructions apply to any riscv64 environment: physical hardware
(SBCs, servers), QEMU virtual machines, or cross-compilation from another
architecture. Where the process differs between native and cross builds,
both paths are shown.

## What You Will Produce

By the end of this guide you will have:

1. **Kubernetes binaries** -- kubelet, kubeadm, kubectl, kube-apiserver,
   kube-controller-manager, kube-scheduler, kube-proxy
2. **Kubernetes container images** -- control plane components, pause
3. **Ecosystem container images** -- etcd, CoreDNS, Flannel
4. **Dependency base images** -- go-runner, distroless-iptables, setcap
5. All artifacts verified and ready for cluster deployment

## Prerequisites

### Container engine: podman

This guide uses podman as the container engine. The `podman-docker` package
provides a `docker` CLI compatibility layer so that Kubernetes build tooling
(which invokes `docker`) works unmodified. All `docker` commands in this guide
run through podman.

### For native builds (on riscv64 hardware or VM)

- Debian Trixie (13) for riscv64
- 8 GB RAM minimum (16 GB recommended)
- 30 GB free disk space
- Internet connectivity

```bash
sudo apt-get update
sudo apt-get install -y git make gcc rsync podman podman-docker containerd
```

### For cross-compilation (from amd64/arm64)

- Linux distribution with podman and Go
- Cross-compiler toolchain (for CGO-enabled kubelet)

```bash
# Debian/Ubuntu
sudo apt-get install podman podman-docker \
  gcc-riscv64-linux-gnu libc6-dev-riscv64-cross

# Fedora (see CGO note in building.md)
sudo dnf install podman podman-docker gcc-riscv64-linux-gnu

# Register QEMU binfmt for cross-architecture container builds
podman run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Common: Go toolchain

The Go version must match the `.go-version` file in the Kubernetes source tree.

```bash
# On riscv64 native
GO_VERSION=$(cat .go-version)
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-riscv64.tar.gz" \
  | sudo tar -C /usr/local -xz
export PATH="/usr/local/go/bin:$PATH"

# On amd64/arm64 (Go manages cross-compilation internally)
GO_VERSION=$(cat .go-version)
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
  | sudo tar -C /usr/local -xz
export PATH="/usr/local/go/bin:$PATH"
```

### Common: Kubernetes source

```bash
git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes
git checkout v1.36.0   # target release

# Apply the riscv64 build system patches (until merged upstream)
git remote add riscv https://github.com/riseproject-dev/kubernetes-riscv.git
git fetch riscv riscv-support
git cherry-pick riscv/riscv-support~9..riscv/riscv-support
```

## Step 1: Build Kubernetes Binaries

### Native build (on riscv64)

```bash
make all \
  WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl \
        cmd/kube-apiserver cmd/kube-controller-manager \
        cmd/kube-scheduler cmd/kube-proxy"
```

Binaries appear in `_output/local/bin/linux/riscv64/`.

### Cross-compile (from amd64/arm64)

```bash
# Static binaries (all components except kubelet)
KUBE_BUILD_PLATFORMS=linux/riscv64 make all \
  WHAT="cmd/kubectl cmd/kubeadm cmd/kube-apiserver \
        cmd/kube-controller-manager cmd/kube-scheduler cmd/kube-proxy"

# kubelet (choose one):

# Option A: Static kubelet (no seccomp support, no cross-compiler needed)
KUBE_BUILD_PLATFORMS=linux/riscv64 KUBE_STATIC_OVERRIDES=kubelet \
  make all WHAT="cmd/kubelet"

# Option B: CGO kubelet (requires libc6-dev-riscv64-cross on Debian/Ubuntu)
KUBE_BUILD_PLATFORMS=linux/riscv64 make all WHAT="cmd/kubelet"
```

### Verify binaries

```bash
file _output/local/bin/linux/riscv64/kubectl
# ELF 64-bit LSB executable, UCB RISC-V, double-float ABI, ...

# Quick functional test (on riscv64, or via QEMU user-mode on the host)
qemu-riscv64-static _output/local/bin/linux/riscv64/kubectl version --client
# Client Version: v1.36.0 ... Platform: linux/riscv64
```

## Step 2: Build Dependency Base Images

These images replace upstream Kubernetes base images that don't include
riscv64 variants. They must be built before the component images.

All images use Debian Trixie as their base and target `linux/riscv64`.

```bash
REGISTRY=ghcr.io/riseproject-dev
GO_VERSION=$(cat .go-version)
PLATFORM=linux/riscv64
```

### Ensure buildx is available

podman supports `buildx build` natively via its Docker CLI compatibility.
If using Docker directly, create a buildx builder:

```bash
docker buildx inspect riscv64-builder >/dev/null 2>&1 || \
  docker buildx create --name riscv64-builder --use
```

### go-runner

Base image for statically-linked Kubernetes binaries. Provides log routing
and signal forwarding.

```bash
docker buildx build --platform ${PLATFORM} \
  --build-arg GO_VERSION=${GO_VERSION} \
  -t ${REGISTRY}/go-runner:v2.4.0-go${GO_VERSION}-trixie.0 \
  --load \
  riscv64/images/go-runner/
```

### setcap

Adds Linux capabilities to binaries (used by kube-apiserver for
binding to privileged ports).

```bash
docker buildx build --platform ${PLATFORM} \
  -t ${REGISTRY}/setcap:trixie-v1.0.0 \
  --load \
  riscv64/images/setcap/
```

### distroless-iptables

Base image for kube-proxy. Stages iptables, nftables, ipset, and conntrack
binaries from Debian Trixie into a distroless image.

```bash
docker buildx build --platform ${PLATFORM} \
  --build-arg GORUNNERIMAGE=${REGISTRY}/go-runner:v2.4.0-go${GO_VERSION}-trixie.0 \
  -t ${REGISTRY}/distroless-iptables:v0.9.0-trixie.0 \
  --load \
  riscv64/images/distroless-iptables/
```

## Step 3: Build Kubernetes Component Images

Use the Kubernetes build system with environment variable overrides pointing
to the community base images.

```bash
export KUBE_BUILD_PLATFORMS=linux/riscv64
export KUBE_DOCKER_REGISTRY=${REGISTRY}
export KUBE_GORUNNER_IMAGE=${REGISTRY}/go-runner:v2.4.0-go${GO_VERSION}-trixie.0
export KUBE_PROXY_BASE_IMAGE=${REGISTRY}/distroless-iptables:v0.9.0-trixie.0
export KUBE_BUILD_SETCAP_IMAGE=${REGISTRY}/setcap:trixie-v1.0.0

make release-images
```

This produces:

| Image | Tag |
|-------|-----|
| `${REGISTRY}/kube-apiserver` | `v1.36.0` |
| `${REGISTRY}/kube-controller-manager` | `v1.36.0` |
| `${REGISTRY}/kube-scheduler` | `v1.36.0` |
| `${REGISTRY}/kube-proxy` | `v1.36.0` |

### Build the pause image

```bash
cd build/pause
make ARCH=riscv64 TAG=3.10.2 REGISTRY=${REGISTRY}
cd ../..
```

## Step 4: Build Ecosystem Component Images

These are the non-Kubernetes components required for a functional cluster.

### etcd

etcd does not officially support riscv64. The Dockerfile sets
`ETCD_UNSUPPORTED_ARCH=riscv64` automatically. See
[known-issues.md](known-issues.md) for runtime configuration details.

```bash
docker buildx build --platform ${PLATFORM} \
  --build-arg ETCD_VERSION=v3.5.21 \
  --build-arg GO_VERSION=${GO_VERSION} \
  -t ${REGISTRY}/etcd:v3.5.21-riscv64 \
  --load \
  riscv64/ecosystem/etcd/
```

### CoreDNS

```bash
docker buildx build --platform ${PLATFORM} \
  --build-arg COREDNS_VERSION=v1.12.1 \
  --build-arg GO_VERSION=${GO_VERSION} \
  -t ${REGISTRY}/coredns:v1.12.1-riscv64 \
  --load \
  riscv64/ecosystem/coredns/
```

### Flannel

```bash
docker buildx build --platform ${PLATFORM} \
  --build-arg FLANNEL_VERSION=v0.28.0 \
  --build-arg GO_VERSION=${GO_VERSION} \
  -t ${REGISTRY}/flannel:v0.28.0-riscv64 \
  --load \
  riscv64/ecosystem/flannel/
```

## Step 5: Verify All Artifacts

### Binaries

```bash
for bin in kubectl kubeadm kubelet kube-apiserver \
           kube-controller-manager kube-scheduler kube-proxy; do
  echo -n "${bin}: "
  file _output/local/bin/linux/riscv64/${bin} | grep -q "RISC-V" && echo "OK" || echo "FAIL"
done
```

### Container images

```bash
K8S_VERSION=v1.36.0

echo "=== Kubernetes component images ==="
for img in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
  echo -n "${img}: "
  docker inspect ${REGISTRY}/${img}:${K8S_VERSION} --format '{{.Architecture}}' 2>/dev/null || echo "MISSING"
done

echo "=== Dependency images ==="
for img in "go-runner:v2.4.0-go${GO_VERSION}-trixie.0" \
           "distroless-iptables:v0.9.0-trixie.0" \
           "setcap:trixie-v1.0.0" \
           "pause:3.10.2"; do
  echo -n "${img}: "
  docker inspect ${REGISTRY}/${img} --format '{{.Architecture}}' 2>/dev/null || echo "MISSING"
done

echo "=== Ecosystem images ==="
for img in "etcd:v3.5.21-riscv64" "coredns:v1.12.1-riscv64" "flannel:v0.28.0-riscv64"; do
  echo -n "${img}: "
  docker inspect ${REGISTRY}/${img} --format '{{.Architecture}}' 2>/dev/null || echo "MISSING"
done
```

### Functional verification

On a riscv64 system (or via `qemu-riscv64-static`):

```bash
# Binaries produce correct output
kubectl version --client         # shows Platform: linux/riscv64
kubeadm version                  # shows Platform: linux/riscv64
kubeadm config print init-defaults  # generates valid YAML
kubelet --version
kube-apiserver --version
kube-scheduler --version
kube-proxy --version
```

## Step 6: Publish Artifacts

### Push container images to GHCR

```bash
# podman-docker passes this through to `podman login`
echo ${GITHUB_TOKEN} | docker login ghcr.io -u ${GITHUB_USER} --password-stdin

K8S_VERSION=v1.36.0

# Kubernetes components
for img in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
  docker push ${REGISTRY}/${img}:${K8S_VERSION}
done

# Pause
docker push ${REGISTRY}/pause:3.10.2

# Dependency images
docker push ${REGISTRY}/go-runner:v2.4.0-go${GO_VERSION}-trixie.0
docker push ${REGISTRY}/distroless-iptables:v0.9.0-trixie.0
docker push ${REGISTRY}/setcap:trixie-v1.0.0

# Ecosystem
docker push ${REGISTRY}/etcd:v3.5.21-riscv64
docker push ${REGISTRY}/coredns:v1.12.1-riscv64
docker push ${REGISTRY}/flannel:v0.28.0-riscv64
```

### Package binaries for distribution

```bash
K8S_VERSION=v1.36.0

tar czf kubernetes-server-linux-riscv64-${K8S_VERSION}.tar.gz \
  -C _output/local/bin/linux/riscv64 \
  kube-apiserver kube-controller-manager kube-scheduler kube-proxy kubelet

tar czf kubernetes-node-linux-riscv64-${K8S_VERSION}.tar.gz \
  -C _output/local/bin/linux/riscv64 \
  kubelet kubeadm kubectl

tar czf kubernetes-client-linux-riscv64-${K8S_VERSION}.tar.gz \
  -C _output/local/bin/linux/riscv64 \
  kubectl
```

### Create a GitHub release (optional)

```bash
gh release create ${K8S_VERSION}-riscv64 \
  --repo riseproject-dev/kubernetes-riscv \
  --title "Kubernetes ${K8S_VERSION} for riscv64" \
  --notes "Community build of Kubernetes ${K8S_VERSION} for linux/riscv64.

**This is NOT an official Kubernetes release.** See the
[build guide](https://github.com/riseproject-dev/kubernetes-riscv/tree/riscv-support/riscv64)
for details.

Container images: \`ghcr.io/riseproject-dev/\`" \
  kubernetes-server-linux-riscv64-${K8S_VERSION}.tar.gz \
  kubernetes-node-linux-riscv64-${K8S_VERSION}.tar.gz \
  kubernetes-client-linux-riscv64-${K8S_VERSION}.tar.gz
```

## Artifact Summary

Complete inventory of artifacts produced by this guide:

### Binaries

| Binary | Purpose | Package |
|--------|---------|---------|
| kube-apiserver | API server | server |
| kube-controller-manager | Controller manager | server |
| kube-scheduler | Scheduler | server |
| kube-proxy | Network proxy | server |
| kubelet | Node agent | server, node |
| kubeadm | Cluster bootstrap | node |
| kubectl | CLI client | node, client |

### Container Images

| Image | Base | Purpose |
|-------|------|---------|
| `kube-apiserver:v1.36.0` | go-runner | Control plane |
| `kube-controller-manager:v1.36.0` | go-runner | Control plane |
| `kube-scheduler:v1.36.0` | go-runner | Control plane |
| `kube-proxy:v1.36.0` | distroless-iptables | Node networking |
| `pause:3.10.2` | scratch | Pod sandbox |
| `etcd:v3.5.21-riscv64` | distroless/static-debian13 | Key-value store |
| `coredns:v1.12.1-riscv64` | distroless/static-debian13 | Cluster DNS |
| `flannel:v0.28.0-riscv64` | debian:trixie-slim | Pod network |

### Dependency Images (not deployed directly)

| Image | Purpose |
|-------|---------|
| `go-runner:v2.4.0-go${GO_VERSION}-trixie.0` | Base for K8s binaries |
| `distroless-iptables:v0.9.0-trixie.0` | Base for kube-proxy |
| `setcap:trixie-v1.0.0` | Capabilities for kube-apiserver |

## Tier 3 Compliance Checklist

This build process satisfies all Tier 3 (Community Supported) requirements
from the [Platform Support Tiers Policy](https://github.com/kubernetes/sig-release/blob/master/release-engineering/platforms/README.md):

- [x] **Documented build process** -- This guide, publicly available
- [x] **No official artifacts** -- All artifacts published under
      `ghcr.io/riseproject-dev/`, not `registry.k8s.io/`
- [x] **No project CI** -- No Kubernetes CI infrastructure used or requested
- [x] **Clear disclaimers** -- All releases marked as community builds
- [x] **Community maintainers identified** -- RISE Project
- [x] **Reproducible** -- Build from tagged Kubernetes source + documented patches
- [x] **Complete** -- All components needed for a functional cluster

## Next Steps

With all artifacts built and published:

1. **Deploy a cluster** -- Follow [cluster-setup.md](cluster-setup.md)
2. **Test in QEMU** -- Follow [qemu-testing.md](qemu-testing.md)
3. **Run conformance tests** -- `sonobuoy run --mode=certified-conformance`
