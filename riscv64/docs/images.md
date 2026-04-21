# Building Container Images for riscv64

This guide covers building Kubernetes component container images for
`linux/riscv64` using the community dependency images on Debian Trixie.

## Prerequisites

- podman with podman-docker (recommended), or Docker with buildx plugin
- QEMU user-static for cross-architecture builds (if building on amd64):
  ```bash
  podman run --rm --privileged multiarch/qemu-user-static --reset -p yes
  ```
- Kubernetes source tree with riscv64 binaries already built (see [building.md](building.md))

Install podman:
```bash
# Debian/Ubuntu
sudo apt-get install podman podman-docker

# Fedora
sudo dnf install podman podman-docker
```

## Dependency Images

The Kubernetes component images depend on base images. The official base images
do not include riscv64 variants, so we provide community equivalents:

| Upstream Image | Community riscv64 Image | Purpose |
|---------------|------------------------|---------|
| `registry.k8s.io/build-image/go-runner` | `ghcr.io/riseproject-dev/go-runner` | Base for static binaries |
| `registry.k8s.io/build-image/distroless-iptables` | `ghcr.io/riseproject-dev/distroless-iptables` | Base for kube-proxy |
| `registry.k8s.io/build-image/setcap` | `ghcr.io/riseproject-dev/setcap` | Capabilities for kube-apiserver |
| `registry.k8s.io/build-image/kube-cross` | `ghcr.io/riseproject-dev/kube-cross` | Cross-compilation environment |

### Build the dependency images

```bash
# go-runner
docker buildx build --platform linux/riscv64 \
  -t ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0 \
  riscv64/images/go-runner/

# setcap
docker buildx build --platform linux/riscv64 \
  -t ghcr.io/riseproject-dev/setcap:trixie-v1.0.0 \
  riscv64/images/setcap/

# distroless-iptables (depends on go-runner)
docker buildx build --platform linux/riscv64 \
  --build-arg GORUNNERIMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0 \
  -t ghcr.io/riseproject-dev/distroless-iptables:v0.9.0-trixie.0 \
  riscv64/images/distroless-iptables/
```

## Building Kubernetes Component Images

Once binaries are built and dependency images are available, build the
component images using the Kubernetes build system with env var overrides:

```bash
export KUBE_BUILD_PLATFORMS=linux/riscv64
export KUBE_DOCKER_REGISTRY=ghcr.io/riseproject-dev
export KUBE_GORUNNER_IMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0
export KUBE_PROXY_BASE_IMAGE=ghcr.io/riseproject-dev/distroless-iptables:v0.9.0-trixie.0
export KUBE_APISERVER_BASE_IMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0
export KUBE_CONTROLLER_MANAGER_BASE_IMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0
export KUBE_SCHEDULER_BASE_IMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0
export KUBE_BUILD_SETCAP_IMAGE=ghcr.io/riseproject-dev/setcap:trixie-v1.0.0

make release-images
```

### Or build individual component images manually

Each component image is a simple copy of the binary into the base image:

```bash
# Example: kube-apiserver
docker buildx build --platform linux/riscv64 \
  --build-arg BASEIMAGE=ghcr.io/riseproject-dev/go-runner:v2.4.0-go1.26.2-trixie.0 \
  --build-arg BINARY=kube-apiserver \
  -t ghcr.io/riseproject-dev/kube-apiserver:v1.32.0 \
  -f build/server-image/Dockerfile \
  _output/local/bin/linux/riscv64/
```

## Building the Pause Image

The pause image is built from the `build/pause/` directory using the
cross-compilation triple added by the riscv64 patches:

```bash
cd build/pause
make ARCH=riscv64 TAG=3.10.2 REGISTRY=ghcr.io/riseproject-dev
```

This requires the kube-cross image with `riscv64-linux-gnu-gcc`.
Override if needed:

```bash
make ARCH=riscv64 TAG=3.10.2 REGISTRY=ghcr.io/riseproject-dev \
  KUBE_CROSS_IMAGE=ghcr.io/riseproject-dev/kube-cross \
  KUBE_CROSS_VERSION=v1.36.0-go1.26.2-trixie.0
```

## Building Ecosystem Component Images

```bash
# etcd
docker buildx build --platform linux/riscv64 \
  --build-arg ETCD_VERSION=v3.5.21 \
  -t ghcr.io/riseproject-dev/etcd:v3.5.21-riscv64 \
  riscv64/ecosystem/etcd/

# CoreDNS
docker buildx build --platform linux/riscv64 \
  --build-arg COREDNS_VERSION=v1.12.1 \
  -t ghcr.io/riseproject-dev/coredns:v1.12.1-riscv64 \
  riscv64/ecosystem/coredns/

# Flannel
docker buildx build --platform linux/riscv64 \
  --build-arg FLANNEL_VERSION=v0.28.0 \
  -t ghcr.io/riseproject-dev/flannel:v0.28.0-riscv64 \
  riscv64/ecosystem/flannel/
```

## Pushing Images

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Push all images
for img in go-runner setcap distroless-iptables pause \
           kube-apiserver kube-controller-manager kube-scheduler kube-proxy \
           etcd coredns flannel; do
  docker push ghcr.io/riseproject-dev/${img}:TAG
done
```

## Multi-Arch Manifests (Optional)

To create manifest lists that support both amd64 and riscv64:

```bash
docker manifest create ghcr.io/riseproject-dev/pause:3.10.2 \
  ghcr.io/riseproject-dev/pause:3.10.2-linux-amd64 \
  ghcr.io/riseproject-dev/pause:3.10.2-linux-riscv64

docker manifest annotate --os linux --arch riscv64 \
  ghcr.io/riseproject-dev/pause:3.10.2 \
  ghcr.io/riseproject-dev/pause:3.10.2-linux-riscv64

docker manifest push ghcr.io/riseproject-dev/pause:3.10.2
```
