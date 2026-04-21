# QEMU Testing Environment for riscv64

This guide sets up a QEMU-based riscv64 virtual machine running Debian Trixie
for testing Kubernetes binaries and container images. This provides a
reproducible test environment without requiring physical RISC-V hardware.

## Host Prerequisites

A Linux host (x86_64 or arm64) with:

- QEMU 8.0+ with riscv64 system emulation
- EDK2 UEFI firmware for RISC-V
- qemu-user-static (for fast binary-only testing)
- 16 GB free RAM (8 GB allocated to the VM)
- 25 GB free disk space

### Install packages

```bash
# Debian/Ubuntu
sudo apt-get install qemu-system-misc qemu-user-static \
  ovmf edk2-riscv64 podman podman-docker

# Fedora
sudo dnf install qemu-system-riscv qemu-user-static-riscv \
  edk2-riscv64 podman podman-docker
```

`podman-docker` provides `docker` CLI compatibility so that the Kubernetes
build system and the container image build commands in
[packaging.md](packaging.md) work unchanged.

### Verify UEFI firmware

```bash
ls /usr/share/edk2/riscv/RISCV_VIRT_CODE.qcow2   # Fedora
ls /usr/share/OVMF/RISCV_VIRT_CODE.fd              # Debian (may vary)
```

If your distribution provides `.fd` files instead of `.qcow2`, convert them:

```bash
qemu-img convert -f raw -O qcow2 RISCV_VIRT_CODE.fd RISCV_VIRT_CODE.qcow2
qemu-img resize RISCV_VIRT_CODE.qcow2 32M
```

The pflash devices on the RISC-V virt machine require 32 MB images.

## Quick Verification with QEMU User-Mode

The fastest way to test riscv64 binaries. No VM needed -- QEMU translates
riscv64 instructions on the host CPU.

```bash
# Build binaries (see building.md)
KUBE_BUILD_PLATFORMS=linux/riscv64 KUBE_STATIC_OVERRIDES=kubelet \
  make all WHAT="cmd/kubectl cmd/kubeadm cmd/kubelet \
    cmd/kube-apiserver cmd/kube-controller-manager \
    cmd/kube-scheduler cmd/kube-proxy"

# Test with qemu-riscv64-static
qemu-riscv64-static _output/local/bin/linux/riscv64/kubectl version --client
# Client Version: v1.36.0 ... Platform: linux/riscv64

qemu-riscv64-static _output/local/bin/linux/riscv64/kubeadm version
qemu-riscv64-static _output/local/bin/linux/riscv64/kubelet --version
qemu-riscv64-static _output/local/bin/linux/riscv64/kube-apiserver --version

# Verify ELF format
file _output/local/bin/linux/riscv64/kubectl
# ELF 64-bit LSB executable, UCB RISC-V, double-float ABI, ...
```

If `binfmt_misc` is configured for riscv64, the binaries can be run directly
without the `qemu-riscv64-static` prefix:

```bash
# Register binfmt (persistent across reboots)
podman run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Now riscv64 binaries run transparently
_output/local/bin/linux/riscv64/kubectl version --client
```

## Full VM Setup

A full system-mode VM boots Debian Trixie on emulated RISC-V hardware,
providing a complete test environment with kernel, init system, networking,
and container runtime.

### Download the Debian Trixie cloud image

```bash
mkdir -p _tmp/qemu-riscv64 && cd _tmp/qemu-riscv64

# The 'generic' variant includes cloud-init for automated configuration
curl -fSLO https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-riscv64-daily.qcow2

# Resize to give headroom for packages, container images, and binaries
qemu-img resize debian-13-generic-riscv64-daily.qcow2 20G
```

### Create the cloud-init seed ISO

Cloud-init configures the VM on first boot (hostname, user accounts,
SSH keys, test scripts).

```bash
mkdir -p cidata

cat > cidata/meta-data << 'META'
instance-id: riscv64-k8s-test
local-hostname: riscv64-test
META

# Generate an SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/id_riscv_test -N "" -q 2>/dev/null || true
SSH_PUB=$(cat ~/.ssh/id_riscv_test.pub)

cat > cidata/user-data << USERDATA
#cloud-config
users:
  - default
  - name: k8s
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${SSH_PUB}
ssh_pwauth: false
USERDATA

# Build the seed ISO
mkisofs -output cidata.iso -volid cidata -joliet -rock \
  cidata/meta-data cidata/user-data
```

### Create a writable UEFI variables file

```bash
# Fedora
cp /usr/share/edk2/riscv/RISCV_VIRT_VARS.qcow2 RISCV_VIRT_VARS.qcow2

# Debian (adjust path as needed)
# cp /usr/share/OVMF/RISCV_VIRT_VARS.qcow2 RISCV_VIRT_VARS.qcow2

# If only .fd is available, convert it:
# qemu-img convert -f raw -O qcow2 RISCV_VIRT_VARS.fd RISCV_VIRT_VARS.qcow2
# qemu-img resize RISCV_VIRT_VARS.qcow2 32M
```

### Boot the VM

```bash
qemu-system-riscv64 \
  -machine virt,acpi=on \
  -cpu rva23s64 \
  -smp 4 -m 8G \
  -drive if=pflash,format=qcow2,unit=0,file=/usr/share/edk2/riscv/RISCV_VIRT_CODE.qcow2,readonly=on \
  -drive if=pflash,format=qcow2,unit=1,file=RISCV_VIRT_VARS.qcow2 \
  -drive file=debian-13-generic-riscv64-daily.qcow2,format=qcow2,if=virtio \
  -drive file=cidata.iso,format=raw,if=virtio \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -nographic
```

The boot sequence is: EDK2 UEFI -> GRUB -> Linux 6.12+ -> cloud-init -> login.

To run in the background, redirect output:

```bash
nohup qemu-system-riscv64 [options above] > boot.log 2>&1 &
```

### Connect via SSH

```bash
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_riscv_test -p 2222 k8s@localhost
```

### Transfer and test binaries

```bash
# Copy binaries to the VM
scp -i ~/.ssh/id_riscv_test -P 2222 \
  _output/local/bin/linux/riscv64/{kubectl,kubeadm,kubelet} \
  k8s@localhost:~/

# On the VM: verify
ssh -i ~/.ssh/id_riscv_test -p 2222 k8s@localhost \
  "./kubectl version --client && ./kubeadm version && ./kubelet --version"
```

### Share host directories with 9p (alternative to scp)

Add to the QEMU command line:

```bash
  -virtfs local,path=_output/local/bin/linux/riscv64,mount_tag=k8sbin,security_model=mapped-xattr,readonly=on
```

Then inside the VM:

```bash
sudo mkdir -p /mnt/k8s
sudo mount -t 9p k8sbin /mnt/k8s -o trans=virtio,ro
/mnt/k8s/kubectl version --client
```

## QEMU Machine Configuration

### CPU profiles

| Profile | Description |
|---------|-------------|
| `rva23s64` | RVA23 (2024 standard, ACPI capable). Recommended. |
| `rv64` | Generic RV64GC. Broadest compatibility. |
| `max` | All available extensions. May expose QEMU bugs. |

### Performance notes

QEMU system-mode riscv64 emulation on x86_64 is approximately 20-50x slower
than native execution. Expect:

| Operation | Approximate time |
|-----------|-----------------|
| Boot to login | 30-60 seconds |
| `kubectl version` | 2-5 seconds |
| `kubeadm init` | 10-20 minutes |
| Full cluster boot | 15-30 minutes |

For faster iteration, use QEMU user-mode (`qemu-riscv64-static`) for binary
testing and reserve the full VM for integration testing.

### Networking

The default `-netdev user` configuration provides:
- Guest IP: 10.0.2.15 (NAT)
- DNS: 10.0.2.3
- Host-to-guest SSH via `-hostfwd=tcp::2222-:22`
- Guest-to-host internet access (via host NAT)

For multi-node clusters, use TAP networking or bridge networking instead.

## Running a Single-Node Cluster in QEMU

Once the VM is running and binaries are installed:

```bash
# On the VM: install containerd, CNI plugins, configure kubelet
# (follow cluster-setup.md, everything applies identically)

# Install podman inside the VM for image management
sudo apt-get install -y podman podman-docker

# Pre-pull and tag community images for kubeadm (see cluster-setup.md)
# ...

# Initialize single-node cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verify
kubectl get nodes
kubectl run test --image=debian:trixie-slim -- sleep infinity
kubectl exec test -- uname -m
# riscv64
```

If the cluster fails to initialize or pods remain pending, consult
[known-issues.md](known-issues.md) for common riscv64-specific problems
(etcd architecture flags, pause image configuration).

## Cleanup

```bash
# Shut down the VM
ssh -i ~/.ssh/id_riscv_test -p 2222 k8s@localhost "sudo poweroff"

# Or kill QEMU
kill $(pgrep -f "qemu-system-riscv64.*riscv64-test")

# Remove test artifacts
rm -rf _tmp/qemu-riscv64
rm -f ~/.ssh/id_riscv_test{,.pub}
```
