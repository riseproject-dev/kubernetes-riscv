# Cluster Setup on Debian Trixie (riscv64)

This guide covers setting up a Kubernetes cluster on RISC-V hardware
running Debian Trixie (13) using kubeadm.

## Hardware Requirements

### Control Plane Node
- RISC-V board/server with 4+ cores
- 8 GB RAM minimum (16 GB recommended)
- 30 GB disk space
- Network connectivity

### Worker Nodes
- RISC-V board/server with 2+ cores
- 4 GB RAM minimum
- 20 GB disk space

### Tested Hardware
- StarFive VisionFive 2
- SiFive HiFive Unmatched
- Milk-V Pioneer
- QEMU riscv64 virtual machines

## OS Setup

Install Debian Trixie for riscv64 from the official installer:
https://www.debian.org/releases/trixie/

### System prerequisites (all nodes)

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl settings
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

## Install Container Runtime

containerd provides official riscv64 binaries.

```bash
# Install containerd from Debian repos
sudo apt-get update
sudo apt-get install -y containerd

# Generate default config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

### Configure the sandbox (pause) image

Replace the default pause image with the community riscv64 image:

```bash
# For containerd v2.x
sudo sed -i 's|registry.k8s.io/pause:.*|ghcr.io/riseproject-dev/pause:3.10.2|' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

## Install CNI Plugins

```bash
CNI_VERSION=$(curl -s https://api.github.com/repos/containernetworking/plugins/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo mkdir -p /opt/cni/bin
curl -fsSL "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-riscv64-${CNI_VERSION}.tgz" \
  | sudo tar -C /opt/cni/bin -xz
```

## Install Kubernetes Binaries

### From community builds

```bash
K8S_VERSION=v1.32.0

# Download pre-built binaries (when available)
# curl -fsSL "https://github.com/riseproject-dev/kubernetes-riscv/releases/download/${K8S_VERSION}/kubernetes-${K8S_VERSION}-riscv64-linux.tar.gz" | sudo tar -C /usr/local/bin -xz

# Or copy binaries built from source (see building.md)
sudo cp _output/local/bin/linux/riscv64/{kubelet,kubeadm,kubectl} /usr/local/bin/
sudo chmod +x /usr/local/bin/{kubelet,kubeadm,kubectl}
```

### Configure kubelet systemd service

```bash
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /etc/systemd/system/kubelet.service.d

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
ExecStart=
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

sudo systemctl daemon-reload
sudo systemctl enable kubelet
```

## Pre-Pull Images (Control Plane)

Pull the community riscv64 images before running kubeadm:

```bash
REGISTRY=ghcr.io/riseproject-dev
K8S_VERSION=v1.32.0

for img in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
  sudo ctr image pull ${REGISTRY}/${img}:${K8S_VERSION}
  sudo ctr image tag ${REGISTRY}/${img}:${K8S_VERSION} registry.k8s.io/${img}:${K8S_VERSION}
done

sudo ctr image pull ${REGISTRY}/pause:3.10.2
sudo ctr image tag ${REGISTRY}/pause:3.10.2 registry.k8s.io/pause:3.10.2

sudo ctr image pull ${REGISTRY}/etcd:v3.5.21-riscv64
sudo ctr image tag ${REGISTRY}/etcd:v3.5.21-riscv64 registry.k8s.io/etcd:3.5.21-0

sudo ctr image pull ${REGISTRY}/coredns:v1.12.1-riscv64
sudo ctr image tag ${REGISTRY}/coredns:v1.12.1-riscv64 registry.k8s.io/coredns/coredns:v1.12.1
```

## Initialize the Cluster (Control Plane Only)

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=${K8S_VERSION}
```

### Configure kubectl

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### (Optional) Allow pods on control plane

For single-node clusters:
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

## Install Pod Network (Flannel)

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

If the default Flannel image does not include riscv64, patch the DaemonSet:

```bash
kubectl set image daemonset/kube-flannel-ds \
  -n kube-flannel \
  kube-flannel=ghcr.io/riseproject-dev/flannel:v0.28.0-riscv64
```

## Join Worker Nodes

On the control plane, generate a join token:
```bash
kubeadm token create --print-join-command
```

On each worker node (after installing binaries, containerd, CNI, and
pre-pulling the pause image):
```bash
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

## Verify

```bash
# Check nodes
kubectl get nodes -o wide
# NAME     STATUS   ROLES           AGE   VERSION   INTERNAL-IP   OS-IMAGE           KERNEL-VERSION   CONTAINER-RUNTIME   ARCH
# node1    Ready    control-plane   5m    v1.32.0   10.0.0.1      Debian Trixie      6.x.x            containerd://2.x    riscv64

# Check system pods
kubectl get pods -n kube-system

# Verify architecture
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'
# riscv64

# Deploy a test pod
kubectl run test --image=debian:trixie-slim --command -- sleep infinity
kubectl exec test -- uname -m
# riscv64
```
