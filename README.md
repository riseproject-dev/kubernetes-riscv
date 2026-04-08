# Kubernetes for RISC-V (riscv64)

Community-maintained build of [Kubernetes](https://github.com/kubernetes/kubernetes)
for `linux/riscv64`, targeting [Debian Trixie (13)](https://www.debian.org/releases/trixie/).

**This is NOT an official Kubernetes release.** These are community builds
maintained by the [RISE Project](https://riseproject.dev) with no guarantees
from the Kubernetes project regarding security, availability, or compatibility.

## What This Repository Provides

This repository contains the upstream Kubernetes source tree plus minimal
patches that add `linux/riscv64` to the build system, along with the
supporting infrastructure needed to produce a fully functional Kubernetes
cluster on RISC-V hardware:

- **Build system patches** -- Add riscv64 to platform lists, architecture
  detection, and the pause image Makefile (~50 lines across 8 files)
- **Dependency images** -- Dockerfiles for go-runner, distroless-iptables,
  and setcap base images built on Debian Trixie
- **Ecosystem images** -- Dockerfiles for etcd, CoreDNS, and Flannel
- **CI workflow** -- GitHub Actions workflow using native RISC-V runners
- **Documentation** -- Complete build, packaging, testing, and deployment guides

## Status

| Component | Status | Artifact |
|-----------|--------|----------|
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
KUBE_BUILD_PLATFORMS=linux/riscv64 make all \
  WHAT="cmd/kubelet cmd/kubeadm cmd/kubectl \
        cmd/kube-apiserver cmd/kube-controller-manager \
        cmd/kube-scheduler cmd/kube-proxy"

# Verify
file _output/local/bin/linux/riscv64/kubelet
# ELF 64-bit LSB executable, UCB RISC-V, ...
```

## Documentation

All guides are in [`riscv64/docs/`](riscv64/docs/):

| Guide | Description |
|-------|-------------|
| [Building Binaries](riscv64/docs/building.md) | Native and cross-compilation methods |
| [Building Container Images](riscv64/docs/images.md) | Component and dependency images |
| [Build and Package All Components](riscv64/docs/packaging.md) | End-to-end guide for all Tier 3 artifacts |
| [QEMU Testing Environment](riscv64/docs/qemu-testing.md) | Testing with QEMU user-mode and system-mode |
| [Cluster Setup](riscv64/docs/cluster-setup.md) | kubeadm-based cluster on Debian Trixie |
| [Dependency Status](riscv64/docs/dependencies.md) | Ecosystem component matrix |
| [Known Issues](riscv64/docs/known-issues.md) | Limitations and workarounds |

## Repository Structure

```
.github/workflows/    CI workflow for native riscv64 builds
riscv64/
  docs/               Documentation
  images/             Dockerfiles for K8s dependency images
    go-runner/          Base image for static binaries
    setcap/             Capabilities helper image
    distroless-iptables/  kube-proxy base image
    kube-cross/         Cross-compilation environment
  ecosystem/          Dockerfiles for ecosystem components
    etcd/               Key-value store
    coredns/            Cluster DNS
    flannel/            CNI network plugin
  scripts/            Build and setup automation
  proposal/           Tier 3 proposal for SIG Release
```

All other files in this repository are the unmodified Kubernetes source tree.

## Tier 3 Platform Support

This project targets [Tier 3 (Community Supported)](https://github.com/kubernetes/sig-release/blob/master/release-engineering/platforms/README.md)
status for `linux/riscv64` in the Kubernetes project. Tier 3 requires:

1. A documented, publicly available build process (this repository)
2. No official builds or CI infrastructure from the Kubernetes project
3. Community maintainers identified (RISE Project)

See the [Tier 3 proposal](riscv64/proposal/tier3-proposal.md) for details.

## Prerequisites

- Go 1.26.2+ (or matching the target Kubernetes release)
- podman with podman-docker (for container image builds)
- For cross-compilation: `gcc-riscv64-linux-gnu` and `libc6-dev-riscv64-cross`
- For native builds: RISC-V hardware running Debian Trixie

## Maintenance Policy

Maintained by the [RISE Project](https://riseproject.dev) as part of RISC-V
enablement in upstream open source software.

- **Tracked versions**: Current Kubernetes stable release
- **Update cadence**: Monthly, following upstream releases
- **Support**: Community best-effort via GitHub issues
- **No SLA**: These are community builds, not official Kubernetes releases
- **Architecture**: `linux/riscv64` only
- **Base OS**: Debian Trixie (13) for all container images

## Upstream Kubernetes

This repository is a fork of [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes).
The upstream README, documentation, and contribution guides apply to the
Kubernetes project itself. For upstream Kubernetes information, see
[kubernetes.io](https://kubernetes.io).

## Related Work

- [kubernetes/kubernetes#132836](https://github.com/kubernetes/kubernetes/issues/132836) -- Upstream RISC-V tracking issue
- [kubernetes-riscv](https://github.com/alitariq4589/kubernetes-riscv) -- Cloud-V build scripts
- [CARV-ICS-FORTH/kubernetes-riscv64](https://github.com/CARV-ICS-FORTH/kubernetes-riscv64) -- K3s RISC-V port
- [RISE Project](https://riseproject.dev) -- RISC-V Software Ecosystem

## License

[Apache License 2.0](LICENSE), same as the Kubernetes project.
