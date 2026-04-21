# Dependency Status Matrix

Status of all components required for a functional Kubernetes cluster on
`linux/riscv64` with Debian Trixie (13).

## Go Toolchain

| Component | Version | riscv64 Status |
|-----------|---------|---------------|
| Go compiler | 1.26.2 | First-class port since Go 1.21 |
| CGO | - | Supported with `riscv64-linux-gnu-gcc` |

## Container Runtime

| Component | Version | riscv64 Status | Source |
|-----------|---------|---------------|--------|
| containerd | 2.x | Official riscv64 binaries | [github.com/containerd/containerd](https://github.com/containerd/containerd/releases) |
| runc | 1.2.x | Official riscv64 binaries | [github.com/opencontainers/runc](https://github.com/opencontainers/runc/releases) |
| crun | 1.x | Available in Debian Trixie | `apt-get install crun` |
| CNI plugins | 1.6.x | Official riscv64 binaries | [github.com/containernetworking/plugins](https://github.com/containernetworking/plugins/releases) |

## Kubernetes Components

| Component | Build Method | CGO Required | Notes |
|-----------|-------------|-------------|-------|
| kube-apiserver | `make cross` | No | |
| kube-controller-manager | `make cross` | No | |
| kube-scheduler | `make cross` | No | |
| kube-proxy | `make cross` | No | |
| kubelet | `make cross` | Recommended | seccomp requires CGO |
| kubeadm | `make cross` | No | |
| kubectl | `make cross` | No | |

## Kubernetes Build Images

| Image | Upstream riscv64 | Community Image |
|-------|-----------------|-----------------|
| kube-cross | Not available | `ghcr.io/riseproject-dev/kube-cross` |
| go-runner | Not available | `ghcr.io/riseproject-dev/go-runner` |
| distroless-iptables | Not available | `ghcr.io/riseproject-dev/distroless-iptables` |
| setcap | Not available | `ghcr.io/riseproject-dev/setcap` |
| pause | Not available | `ghcr.io/riseproject-dev/pause` |

## Distroless Base Images

| Image | riscv64 Status |
|-------|---------------|
| `gcr.io/distroless/static-debian13` | Available |
| `gcr.io/distroless/base-debian13` | Available |
| `gcr.io/distroless/cc-debian13` | Available |
| `gcr.io/distroless/static-debian12` | NOT available |
| `gcr.io/distroless/base-debian12` | NOT available |

Note: Only debian13 (Trixie) distroless images include riscv64 manifests.

## Ecosystem Components

| Component | Version | riscv64 Status | Notes |
|-----------|---------|---------------|-------|
| etcd | v3.5.x | Compiles from source | Requires `ETCD_UNSUPPORTED_ARCH=riscv64` |
| CoreDNS | v1.12.x | Compiles from source | Pure Go, no special handling |
| Flannel | v0.28.x | Compiles from source | Includes CNI plugin |
| Helm | v3.x | Official riscv64 binaries | [github.com/helm/helm](https://github.com/helm/helm/releases) |
| crictl | v1.x | Compiles from source | CRI debugging tool |

## Debian Trixie Packages (riscv64)

All required system packages are available for `riscv64` in Debian Trixie:

| Package | Version | Status |
|---------|---------|--------|
| iptables | 1.8.11 | Available |
| nftables | - | Available |
| ipset | 7.22 | Available |
| conntrack-tools | 1.4.8 | Available |
| iproute2 | 6.15.0 | Available |
| libcap2-bin | 2.75 | Available |
| gcc-riscv64-linux-gnu | - | Available (cross-compiler) |

## QEMU Support

| Component | riscv64 Status |
|-----------|---------------|
| qemu-user-static | Supported (binfmt registered) |
| qemu-system-riscv64 | Supported |
| Docker buildx QEMU | Supported via `multiarch/qemu-user-static` |

The Kubernetes source tree includes QEMU binfmt registration for riscv64
in `third_party/multiarch/qemu-user-static/register/qemu-binfmt-conf.sh`.
