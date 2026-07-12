#!/usr/bin/env bash
set -eu

CP_IP=34.124.248.110
mkdir -p /home/wizard/.kube /home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts

ssh -o StrictHostKeyChecking=no -i /home/wizard/.ssh/k8s-deploy ubuntu@${CP_IP} \
  'sudo cat /etc/kubernetes/admin.conf' \
  > /home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts/admin.conf

sed -i "s|server: https://127.0.0.1:6443|server: https://${CP_IP}:6443|" \
  /home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts/admin.conf

cp /home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts/admin.conf /home/wizard/.kube/config
chmod 600 /home/wizard/.kube/config /home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts/admin.conf

export PATH="/home/wizard/.local/bin:$PATH"
echo "kubectl: $(kubectl version --client 2>/dev/null | head -1)"
kubectl get nodes
