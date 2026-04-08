# Proposal: Tier 3 Platform Support for linux/riscv64

## Summary

This proposal requests Tier 3 (Community Supported) platform status for
`linux/riscv64` in Kubernetes, per the
[Platform Support Tiers Policy](https://github.com/kubernetes/sig-release/blob/master/release-engineering/platforms/README.md).

## Motivation

RISC-V is an open-standard instruction set architecture (ISA) with growing
adoption in server, edge, and embedded computing. The RISC-V ecosystem has
matured to the point where Kubernetes can be built and run on riscv64 hardware
with no modifications to the Go source code.

The [RISE Project](https://riseproject.dev) (RISC-V Software Ecosystem), a
Linux Foundation initiative, is coordinating upstream enablement of RISC-V
across open source projects. This proposal is part of that effort.

## Tier 3 Requirements Mapping

Per the platform tiers policy, Tier 3 requires:

### 1. No official builds or artifacts are provided

**Satisfied.** This proposal does not request any changes to the Kubernetes
release process. No official binaries, container images, or release artifacts
will be produced for riscv64.

### 2. No project CI is set up

**Satisfied.** This proposal does not request CI resources or test
infrastructure. No riscv64 jobs will be added to the Kubernetes CI system.

Note: The RISE Project provides free riscv64 GitHub Actions runners
(`ubuntu-24.04-riscv`) which could support future CI integration if/when
Tier 2 is pursued. This infrastructure is already in use by the K3s project
([k3s-io/k3s#13854](https://github.com/k3s-io/k3s/pull/13854)).

### 3. A documented build process is available in the community

**Satisfied.** A comprehensive build guide is maintained at:
https://github.com/riseproject-dev/kubernetes-riscv

The documentation covers:
- Building Kubernetes server binaries via cross-compilation and native builds
- Building all required container images (control plane, pause, ecosystem)
- Setting up a functional cluster on Debian Trixie using kubeadm
- Dependency status matrix for all ecosystem components
- Known issues and workarounds

### 4. External artifacts may be linked with a clear disclaimer

**Satisfied.** Community-built container images are published at
`ghcr.io/riseproject-dev/` with clear disclaimers that these are not official
Kubernetes releases and carry no guarantees from the Kubernetes project.

## Technical Readiness

### Go Toolchain

Go has supported `GOARCH=riscv64` as a **first-class port** since Go 1.21
(August 2023). Kubernetes currently uses Go 1.26.2. All Kubernetes Go code
compiles for riscv64 without modification.

Per the platform tiers policy: platforms where Go treats the architecture as a
first-class port are eligible for any tier. riscv64 is NOT restricted to Tier 3
by Go toolchain classification.

### Build System Changes

A minimal set of mechanical changes (approximately 50 lines across 9 files)
adds riscv64 to the Kubernetes build system's recognized architectures. These
changes follow the exact pattern established by s390x and ppc64le:

- `hack/lib/golang.sh` -- Platform lists and CGO cross-compiler configuration
- `hack/lib/util.sh` -- Host architecture detection
- `build/pause/Makefile` -- Pause image architecture list and cross-compiler triple
- `test/images/image-util.sh` -- QEMU architecture mapping
- `hack/local-up-cluster.sh`, `cluster/get-kube.sh`, `cluster/get-kube-binaries.sh`,
  `cluster/gce/gci/configure.sh`, `cluster/gce/gci/configure-helper.sh` --
  Architecture detection in cluster scripts

PR: (link to upstream PR when submitted)

### Dependency Image Strategy

The official Kubernetes base images (go-runner, distroless-iptables, setcap)
do not currently include riscv64 variants. The community build process uses
the existing environment variable override mechanism in `build/common.sh`:

- `KUBE_GORUNNER_IMAGE` -- Base image for statically-linked binaries
- `KUBE_PROXY_BASE_IMAGE` -- Base image for kube-proxy
- `KUBE_BUILD_SETCAP_IMAGE` -- Capabilities helper image
- `KUBE_CROSS_IMAGE` -- Cross-compilation environment

Community images are built on Debian Trixie (13), which provides full riscv64
package support. The distroless-debian13 base images (static, base, cc) include
riscv64 manifests, merged upstream by Google.

### Ecosystem Readiness

| Component | riscv64 Status |
|-----------|---------------|
| Go 1.26.2 | First-class port |
| containerd | Official riscv64 binaries |
| runc | Official riscv64 binaries |
| CNI plugins | Official riscv64 binaries |
| etcd | Compiles (requires ETCD_UNSUPPORTED_ARCH) |
| CoreDNS | Compiles from source |
| Flannel | Compiles from source |
| Debian Trixie | Full riscv64 architecture support |
| distroless-debian13 | riscv64 manifests available |
| QEMU binfmt | riscv64 registration in K8s tree |

### Existing Community Validation

Multiple independent projects have demonstrated functional Kubernetes clusters
on riscv64:

- **kubernetes-riscv** ([github.com/alitariq4589/kubernetes-riscv](https://github.com/alitariq4589/kubernetes-riscv)) --
  Monthly automated builds and releases, setup scripts for multi-node clusters
- **CARV-ICS-FORTH** ([github.com/CARV-ICS-FORTH/kubernetes-riscv64](https://github.com/CARV-ICS-FORTH/kubernetes-riscv64)) --
  K3s RISC-V port with documented process
- **Talos Linux** -- Unofficial riscv64 port completed
- **vitamin-V** (Barcelona Supercomputing Center) -- Build system patches
  demonstrating compilation on riscv64

## Maintainers

This Tier 3 platform status is maintained by the RISE Project:

- Ludovic Henry (@luhenry) -- RISE Project
- Brian Harrington (@bharrington) -- RISE Project

The RISE Project commits to:
- Maintaining the documented build process
- Publishing updated community images following Kubernetes releases
- Responding to riscv64-specific issues reported via the documentation repository
- Coordinating with SIG Release on platform status

## Path to Tier 2

While not part of this proposal, the following would be needed for future
Tier 2 promotion (requires at least two full release cycles at Tier 3):

1. **KEP** -- A formal Kubernetes Enhancement Proposal
2. **CI on informing dashboard** -- RISE Project riscv64 runners could provide
   this infrastructure
3. **At least two dedicated maintainers** -- Already satisfied
4. **First-class Go toolchain support** -- Already satisfied (since Go 1.21)
5. **Conformance test results** -- Work in progress

## References

- [kubernetes/kubernetes#132836](https://github.com/kubernetes/kubernetes/issues/132836) -- Upstream tracking issue
- [kubernetes/sig-release#2974](https://github.com/kubernetes/sig-release/pull/2974) -- Platform tiers policy
- [RISE Project](https://riseproject.dev) -- RISC-V Software Ecosystem
- [Build guide](https://github.com/riseproject-dev/kubernetes-riscv/tree/riscv-support/riscv64) -- Community documentation
