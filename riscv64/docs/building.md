# Building Kubernetes Binaries for riscv64

This guide covers three methods for building Kubernetes binaries for `linux/riscv64`.

## Prerequisites

All methods require:
- Git
- Go 1.26.2+ (must match the `.go-version` in the Kubernetes source tree)
- The Kubernetes source checked out at the target version

```bash
git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes
git checkout v1.32.0  # or your target version
```

## Method 1: Cross-Compile from amd64/arm64 (Recommended)

The simplest approach. Builds on your existing x86_64 or arm64 workstation.

### Install the cross-compiler toolchain

```bash
# Debian/Ubuntu
sudo apt-get install gcc-riscv64-linux-gnu

# Fedora
sudo dnf install gcc-riscv64-linux-gnu
```

### Build all server binaries

```bash
KUBE_BUILD_PLATFORMS=linux/riscv64 make cross \
  WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl cmd/kube-apiserver \
        cmd/kube-controller-manager cmd/kube-scheduler cmd/kube-proxy"
```

### Build specific binaries

```bash
# Just kubelet and kubectl
KUBE_BUILD_PLATFORMS=linux/riscv64 make cross \
  WHAT="cmd/kubelet cmd/kubectl"
```

### Build without CGO (no cross-compiler needed)

Some binaries can be built without CGO. This avoids the need for
`gcc-riscv64-linux-gnu` but disables features that require cgo (e.g.,
seccomp in kubelet):

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=riscv64 go build -o _output/local/bin/linux/riscv64/kubectl ./cmd/kubectl
```

### Output location

Binaries are placed in:
```
_output/local/bin/linux/riscv64/
```

### Verify

```bash
file _output/local/bin/linux/riscv64/kubelet
# ELF 64-bit LSB executable, UCB RISC-V, RVC, double-float ABI, ...

file _output/local/bin/linux/riscv64/kubectl
# ELF 64-bit LSB executable, UCB RISC-V, RVC, double-float ABI, ...
```

## Method 2: Native Build on riscv64 Hardware

Build directly on a RISC-V machine running Debian Trixie.

### Hardware requirements

- RISC-V board or server (StarFive VisionFive 2, SiFive HiFive, Milk-V, etc.)
- At least 8 GB RAM (16 GB recommended)
- At least 30 GB free disk space
- Debian Trixie (13) for riscv64

### Install build dependencies

```bash
sudo apt-get update
sudo apt-get install -y git make gcc rsync
```

### Install Go

```bash
GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-riscv64.tar.gz" | sudo tar -C /usr/local -xz
export PATH="/usr/local/go/bin:$PATH"
```

### Build

On native hardware, no cross-compilation flags are needed:

```bash
make all \
  WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl cmd/kube-apiserver \
        cmd/kube-controller-manager cmd/kube-scheduler cmd/kube-proxy"
```

Note: Native builds on current RISC-V hardware are significantly slower than
cross-compilation. Expect 30-60 minutes for a full build depending on hardware.

## Method 3: Dockerized Cross-Compile with kube-cross

Use the community kube-cross image for a fully containerized build environment.

### Build using the community kube-cross image

```bash
docker run --rm \
  -v "$PWD":/go/src/k8s.io/kubernetes \
  -w /go/src/k8s.io/kubernetes \
  -e KUBE_BUILD_PLATFORMS=linux/riscv64 \
  ghcr.io/riseproject-dev/kube-cross:v1.36.0-go1.26.2-trixie.0 \
  make cross WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl"
```

### Or use the Kubernetes dockerized build system

Set the `KUBE_CROSS_IMAGE` override to point to the community image:

```bash
export KUBE_CROSS_IMAGE=ghcr.io/riseproject-dev/kube-cross
export KUBE_CROSS_VERSION=v1.36.0-go1.26.2-trixie.0
export KUBE_BUILD_PLATFORMS=linux/riscv64

make cross WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl"
```

## CGO Considerations

Kubernetes uses CGO for certain features:

| Binary | CGO Required | Features Requiring CGO |
|--------|-------------|----------------------|
| kubelet | Recommended | seccomp, device plugins |
| kube-apiserver | No | - |
| kube-controller-manager | No | - |
| kube-scheduler | No | - |
| kube-proxy | No | - |
| kubectl | No | - |
| kubeadm | No | - |

When building with CGO enabled (the default for kubelet), the cross-compiler
`riscv64-linux-gnu-gcc` must be available. The build system uses the
`KUBE_LINUX_RISCV64_CC` environment variable to override the default compiler:

```bash
# Override the cross-compiler (default: riscv64-linux-gnu-gcc)
export KUBE_LINUX_RISCV64_CC=riscv64-linux-gnu-gcc
```

## Troubleshooting

### "riscv64-linux-gnu-gcc: command not found"

Install the cross-compiler:
```bash
sudo apt-get install gcc-riscv64-linux-gnu
```

Or build without CGO:
```bash
export CGO_ENABLED=0
```

### "unsupported GOOS/GOARCH pair"

Ensure you are using Go 1.21 or later. RISC-V (riscv64) has been a first-class
Go port since Go 1.21.

### Build runs out of memory on riscv64 hardware

Limit parallelism:
```bash
make all WHAT="cmd/kubelet" GOFLAGS="-p=2"
```

### KUBE_FASTBUILD not recognizing riscv64

Ensure the build system patches from this repository have been applied. The
`hack/lib/golang.sh` file must include `riscv64` in the `KUBE_FASTBUILD`
host architecture check.
