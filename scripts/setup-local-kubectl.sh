#!/usr/bin/env bash
set -eu

KUBECTL=/home/wizard/.local/bin/kubectl
mkdir -p /home/wizard/.local/bin /home/wizard/.kube

if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o "$KUBECTL"
  chmod +x "$KUBECTL"
fi

grep -q '/home/wizard/.local/bin' /home/wizard/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/wizard/.bashrc

cd /home/wizard/k8s-recovery/kubespray
source venv/bin/activate
export ANSIBLE_HOST_KEY_CHECKING=False

mkdir -p inventory/mycluster/artifacts
ansible -i inventory/mycluster/inventory.ini k8s-cp-1 -b -m fetch \
  -a "src=/etc/kubernetes/admin.conf dest=inventory/mycluster/artifacts/admin.conf flat=yes" \
  >/dev/null

# Fix server URL: admin.conf on node points to localhost; use the public IP
CP_IP=$(grep k8s-cp-1 inventory/mycluster/inventory.ini | awk '{print $2}' | cut -d= -f2)
sed -i "s|server: https://127.0.0.1:6443|server: https://${CP_IP}:6443|" inventory/mycluster/artifacts/admin.conf

cp inventory/mycluster/artifacts/admin.conf /home/wizard/.kube/config
chmod 600 /home/wizard/.kube/config

echo "kubectl: $($KUBECTL version --client --short 2>/dev/null || $KUBECTL version --client)"
echo "kubeconfig: /home/wizard/.kube/config"
$KUBECTL get nodes
