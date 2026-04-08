# Kubernetes RISC-V (riscv64) Build Guide

Community-maintained build process for Kubernetes on `linux/riscv64`, targeting
[Debian Trixie (13)](https://www.debian.org/releases/trixie/). This repository
serves as the documented build process required for
[Tier 3 (Community Supported)](https://github.com/kubernetes/sig-release/blob/master/release-engineering/platforms/README.md)
platform status.

**This is NOT an official Kubernetes release.** These are community builds with
no guarantees from the Kubernetes project regarding security, availability, or
compatibility. See [Maintenance Policy](#maintenance-policy).

## Status

| Component | riscv64 Status | Image |
|-----------|---------------|-------|
| kube-apiserver | Builds from source | `ghcr.io/riseproject-dev/kube-apiserver` |
| kube-controller-manager | Builds from source | `ghcr.io/riseproject-dev/kube-controller-manager` |
| kube-scheduler | Builds from source | `ghcr.io/riseproject-dev/kube-scheduler` |
| kube-proxy | Builds from source | `ghcr.io/riseproject-dev/kube-proxy` |
| kubelet | Builds from source | Binary release |
| kubeadm | Builds from source | Binary release |
| kubectl | Builds from source | Binary release |
| pause | Builds from source | `ghcr.io/riseproject-dev/pause` |
| etcd | Builds (unsupported arch flag) | `ghcr.io/riseproject-dev/etcd` |
| CoreDNS | Builds from source | `ghcr.io/riseproject-dev/coredns` |
| Flannel | Builds from source | `ghcr.io/riseproject-dev/flannel` |
| containerd | Official riscv64 binaries | upstream |
| runc / crun | Official riscv64 binaries | upstream |
| CNI plugins | Official riscv64 binaries | upstream |

## Quick Start

Build Kubernetes binaries for riscv64:

```bash
# Cross-compile from amd64/arm64
KUBE_BUILD_PLATFORMS=linux/riscv64 make cross \
  WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl cmd/kube-apiserver cmd/kube-controller-manager cmd/kube-scheduler cmd/kube-proxy"

# Verify
file _output/local/bin/linux/riscv64/kubelet
# ELF 64-bit LSB executable, UCB RISC-V, ...
```

## Documentation

- [Building Binaries](docs/building.md) -- Native and cross-compilation methods
- [Building Container Images](docs/images.md) -- Component and dependency images
- [Build and Package All Components](docs/packaging.md) -- End-to-end guide for producing all Tier 3 artifacts
- [QEMU Testing Environment](docs/qemu-testing.md) -- Testing with QEMU user-mode and system-mode
- [Cluster Setup](docs/cluster-setup.md) -- kubeadm-based cluster on Debian Trixie
- [Dependency Status](docs/dependencies.md) -- Ecosystem component matrix
- [Known Issues](docs/known-issues.md) -- Limitations and workarounds

## Repository Structure

```
riscv64/
  docs/           Documentation
  images/         Dockerfiles for K8s dependency images
    go-runner/      Base image for static binaries
    setcap/         Capabilities helper image
    distroless-iptables/  kube-proxy base image
    kube-cross/     Cross-compilation environment
  ecosystem/      Dockerfiles for ecosystem components
    etcd/           Key-value store
    coredns/        Cluster DNS
    flannel/        CNI network plugin
  scripts/        Build and setup automation
  proposal/       Tier 3 proposal for SIG Release
```

## Prerequisites

- Go 1.26.2+ (or matching the target Kubernetes release)
- Docker with buildx (for container image builds)
- For cross-compilation: `gcc-riscv64-linux-gnu` package
- For native builds: RISC-V hardware running Debian Trixie

## Maintenance Policy

This build process is maintained by the [RISE Project](https://riseproject.dev)
as part of the effort to enable RISC-V in upstream open source software.

- **Tracked versions**: Current Kubernetes stable release
- **Update cadence**: Monthly, following upstream releases
- **Support**: Community best-effort via GitHub issues
- **No SLA**: These are community builds, not official Kubernetes releases
- **Architecture**: `linux/riscv64` only
- **Base OS**: Debian Trixie (13) for all container images

## Related Work

- [kubernetes/kubernetes#132836](https://github.com/kubernetes/kubernetes/issues/132836) -- Upstream RISC-V tracking issue
- [kubernetes-riscv](https://github.com/alitariq4589/kubernetes-riscv) -- Cloud-V build scripts
- [CARV-ICS-FORTH/kubernetes-riscv64](https://github.com/CARV-ICS-FORTH/kubernetes-riscv64) -- K3s RISC-V port
- [RISE Project](https://riseproject.dev) -- RISC-V Software Ecosystem

## License

This work follows the same [Apache License 2.0](../LICENSE) as the Kubernetes project.
