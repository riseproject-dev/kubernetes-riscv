# Known Issues and Workarounds

## etcd: Unsupported Architecture Flag

etcd does not officially support riscv64. The `ETCD_UNSUPPORTED_ARCH=riscv64`
environment variable must be set at runtime. Without it, etcd refuses to start.

This is set automatically in the community etcd Dockerfile. When using kubeadm,
add the environment variable to the etcd static pod manifest:

```yaml
# /etc/kubernetes/manifests/etcd.yaml
spec:
  containers:
  - name: etcd
    env:
    - name: ETCD_UNSUPPORTED_ARCH
      value: "riscv64"
```

## Build Time on Native Hardware

Building Kubernetes natively on current RISC-V hardware is approximately
9x slower than on x86_64. Cross-compilation from amd64 is strongly
recommended for regular builds.

| Method | Approximate Time |
|--------|-----------------|
| Cross-compile from amd64 | ~10-15 minutes |
| Native on StarFive VisionFive 2 | ~60-90 minutes |
| Native on Milk-V Pioneer | ~30-45 minutes |

To reduce native build time, limit parallelism to avoid OOM:
```bash
make all WHAT="cmd/kubelet" GOFLAGS="-p=2"
```

## Docker Setup Action (GitHub CI)

The `docker/setup-docker-action` GitHub Action does not support riscv64
runners. When using RISE Project riscv64 runners (`ubuntu-24.04-riscv`),
skip this action and rely on the Docker pre-installed on the runner:

```yaml
- uses: docker/setup-docker-action@v4
  if: inputs.arch != 'riscv64'
```

## Pause Image Override

The default pause image (`registry.k8s.io/pause`) does not include an riscv64
variant. All nodes must be configured to use the community pause image.

For containerd v2.x, set in `/etc/containerd/config.toml`:
```toml
[plugins."io.containerd.cri.v1.images"]
  pinned_images = ["ghcr.io/riseproject-dev/pause:3.10.2"]
```

For containerd v1.x:
```toml
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "ghcr.io/riseproject-dev/pause:3.10.2"
```

## kubelet CGO and seccomp

When kubelet is built with `CGO_ENABLED=0`, seccomp support is disabled.
This means seccomp profiles in pod security contexts will not be enforced.
For production clusters, build kubelet with CGO enabled using the
`riscv64-linux-gnu-gcc` cross-compiler.

## No Official Release Artifacts

The Kubernetes project does not produce official binaries or container images
for riscv64. All artifacts must be built from source using this guide or
obtained from community builds. This is consistent with Tier 3 (Community
Supported) status.

## Conformance Test Status

Full Kubernetes conformance test results for riscv64 are not yet available.
Basic cluster operations (pod scheduling, service networking, DNS resolution)
have been validated. Conformance testing is an ongoing effort.

## Protobuf Compiler on riscv64

The protobuf project does not ship pre-built `protoc` binaries for riscv64.
When building on native riscv64 hardware, install protobuf from Debian
packages:
```bash
sudo apt-get install protobuf-compiler
```
