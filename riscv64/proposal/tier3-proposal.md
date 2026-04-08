# Proposal: Tier 3 Platform Support for linux/riscv64

## Summary

This proposal requests Tier 3 (Community Supported) platform status for
`linux/riscv64` in Kubernetes, per the
[Platform Support Tiers Policy](https://github.com/kubernetes/sig-release/blob/master/release-engineering/platforms/README.md).

Per the policy, platforms enter the support framework at Tier 3. This proposal
will be filed as an issue in the
[kubernetes/sig-release](https://github.com/kubernetes/sig-release) repository
for evaluation by lazy consensus.

### Proposed Platform Table Entry

| Platform | Tier | Notes |
|----------|------|-------|
| linux/riscv64 | 3 | server, node, and client |

### Scope

This proposal covers full platform support: server binaries (kube-apiserver,
kube-controller-manager, kube-scheduler, kube-proxy), node binaries (kubelet,
kubeadm), and the client binary (kubectl). This matches the scope of existing
Tier 2 platforms like linux/ppc64le and linux/s390x, but at Tier 3 with no
official builds or CI.

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
will be produced for riscv64. All artifacts are published under the community
namespace `ghcr.io/riseproject-dev/`, not `registry.k8s.io/`.

### 2. No project CI is set up

**Satisfied.** This proposal does not request CI resources or test
infrastructure. No riscv64 jobs will be added to the Kubernetes CI system
(testgrid, prow, or any project dashboard).

Note: The RISE Project provides free riscv64 GitHub Actions runners
(`ubuntu-24.04-riscv`) which could support future CI integration if/when
Tier 2 is pursued. This infrastructure is already in use by the K3s project
([k3s-io/k3s#13854](https://github.com/k3s-io/k3s/pull/13854)).

### 3. A documented build process is available in the community

**Satisfied.** A comprehensive build guide is maintained at:
https://github.com/riseproject-dev/kubernetes-riscv

The documentation covers:
- Building all Kubernetes server, node, and client binaries via cross-compilation and native builds
- Building all required container images (control plane, pause, ecosystem)
- Setting up a functional cluster on Debian Trixie using kubeadm
- QEMU-based testing without physical RISC-V hardware
- End-to-end packaging guide producing all artifacts needed for a functional cluster
- Dependency status matrix for all ecosystem components
- Known issues and workarounds

### 4. External artifacts may be linked with a clear disclaimer

**Satisfied.** Community-built container images and binary tarballs are
published at `ghcr.io/riseproject-dev/` and as GitHub releases on the
documentation repository. All artifacts carry explicit disclaimers:

> **This is NOT an official Kubernetes release.** These are community builds
> with no guarantees from the Kubernetes project regarding security,
> availability, or compatibility.

## Evaluation Criteria

The platform tiers policy defines evaluation criteria that apply across all
tiers. This section addresses each criterion.

### Go Toolchain Classification

Go has supported `GOARCH=riscv64` as a **first-class port** since Go 1.21
(August 2023). Kubernetes currently uses Go 1.26.2. All Kubernetes Go code
compiles for riscv64 without modification.

Per the policy: "Platforms where Go itself treats the architecture as a
secondary port (where build breakages are not guaranteed to be fixed upstream)
are restricted to Tier 3." Because riscv64 is a first-class Go port, it is
**not** restricted to Tier 3 by this criterion and is eligible for any tier.

### Maintainer Commitment

This Tier 3 platform status is maintained by the RISE Project:

- Ludovic Henry (@luhenry) -- RISE Project
- Brian Harrington (@bharrington) -- RISE Project

As Tier 3 maintainers, we commit to:
- Maintaining the documented build process and keeping it current with
  Kubernetes stable releases
- Publishing updated community images and binaries monthly, following
  upstream releases
- Triaging and responding to riscv64-specific issues reported via the
  documentation repository
- Participating in SIG Release communication and responding to inquiries
  about the platform's status
- Providing riscv64 hardware and CI infrastructure access via RISE Project
  GitHub runners
- Maintaining a **draft PR against kubernetes/kubernetes** containing the
  riscv64 build system patches, rebased onto each stable release. This
  serves as a public integration branch that anyone can check out to build
  and test Kubernetes on riscv64 without maintaining their own patch set.
  The draft PR also provides a natural venue for community review and
  feedback on the changes proposed for Tier 2 promotion.

Per the policy, Tier 3 does not create obligations for the Kubernetes project.
Bug reports or feature requests specific to riscv64 may be closed without
action by upstream maintainers.

### User Demand

RISC-V adoption in server and edge computing is accelerating:

- **Hardware availability**: Production RISC-V server boards are shipping
  from multiple vendors (SiFive HiFive Unmatched, StarFive VisionFive 2,
  Milk-V Pioneer, Sophgo SG2042-based systems). Datacenter-class RISC-V
  CPUs are in development from multiple vendors.
- **Linux distribution support**: Debian, Ubuntu, Fedora, openSUSE, and
  Gentoo all provide riscv64 ports. Debian Trixie (13) promotes riscv64
  to a release architecture.
- **Cloud native ecosystem**: containerd, runc, CNI plugins, and the
  distroless base images all ship riscv64 variants. K3s has an active
  riscv64 enablement effort ([k3s-io/k3s#13854](https://github.com/k3s-io/k3s/pull/13854)).
- **Independent community builds**: Multiple independent projects
  (Cloud-V, CARV-ICS-FORTH, vitamin-V) have produced Kubernetes riscv64
  builds, demonstrating organic demand.
- **Industry backing**: The RISE Project is a Linux Foundation initiative
  with members including Google, Intel, Samsung, Qualcomm, NVIDIA, and
  others, focused on enabling RISC-V in upstream open source software.
  RISC-V International projects over 70 billion RISC-V cores shipped
  by 2030.

Tier 3 is appropriate for an architecture at this stage of adoption. Concrete
download and usage statistics will be collected from the community image
registry and binary releases to support a future Tier 2 proposal when demand
warrants it.

### Build and Infrastructure Cost

**Zero impact on the Kubernetes project.** Tier 3 status adds no builds to the
release process, no CI jobs to testgrid or prow, and no infrastructure cost.
The upstream build system changes (~50 lines) are inert unless
`KUBE_BUILD_PLATFORMS=linux/riscv64` is explicitly set. Default builds are
unaffected.

All community builds run on RISE Project infrastructure (riscv64 GitHub
runners and contributor hardware). No Kubernetes project resources are
consumed.

### Ecosystem Support

| Component | riscv64 Status |
|-----------|---------------|
| Go 1.26.2 | First-class port |
| containerd | Official riscv64 binaries (since 1.7) |
| runc | Official riscv64 binaries |
| crun | Official riscv64 binaries |
| CNI plugins | Official riscv64 binaries |
| etcd | Compiles from source (requires ETCD_UNSUPPORTED_ARCH=riscv64) |
| CoreDNS | Compiles from source |
| Flannel | Compiles from source |
| Debian Trixie | Full riscv64 release architecture |
| distroless-debian13 | riscv64 manifests merged upstream (static, base, cc) |
| QEMU binfmt | riscv64 registration already in Kubernetes source tree |

## Technical Details

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

Draft PR: (link to upstream draft PR when submitted)

The draft PR will be kept open and rebased onto each Kubernetes stable
release for the duration of Tier 3. This gives community members a
single branch to check out for building and testing riscv64, and
provides a review surface for the changes that would be merged as part
of a Tier 2 promotion.

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

## Path to Tier 2

While not part of this proposal, the following would be needed for future
Tier 2 promotion. Per the policy, a platform must spend at least two full
release cycles at its current tier without major issues before promotion.

| Tier 2 Requirement | Current Status |
|---------------------|---------------|
| KEP (Kubernetes Enhancement Proposal) | Not yet filed; will be prepared during Tier 3 period |
| CI on informing/conformance dashboard | RISE Project riscv64 runners available; CI integration to be designed with SIG Testing |
| Minimum two dedicated maintainers | Already satisfied (Henry, Harrington) |
| First-class Go toolchain support | Already satisfied (since Go 1.21) |
| Organized as SIG Release subproject with dedicated OWNERS | To be established |
| Promotion plan with no-perma-beta compliance | To be prepared alongside KEP |
| Conformance test results | Work in progress |

A Tier 2 promotion proposal would be filed as a separate issue in
kubernetes/sig-release after at least two full release cycles at Tier 3,
with SIG Testing acknowledgement of proposed CI coverage. The draft PR
maintained during the Tier 3 period would be promoted from draft to a
full PR at that time.

## References

- [kubernetes/kubernetes#132836](https://github.com/kubernetes/kubernetes/issues/132836) -- Upstream tracking issue
- [Platform Support Tiers Policy](https://github.com/kubernetes/sig-release/blob/master/release-engineering/platforms/README.md) -- Governing policy
- [RISE Project](https://riseproject.dev) -- RISC-V Software Ecosystem (Linux Foundation)
- [Build guide](https://github.com/riseproject-dev/kubernetes-riscv/tree/riscv-support/riscv64) -- Community documentation
- [k3s-io/k3s#13854](https://github.com/k3s-io/k3s/pull/13854) -- K3s RISC-V enablement using RISE runners
