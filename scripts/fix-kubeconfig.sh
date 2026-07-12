#!/usr/bin/env bash
sed -i 's|server: https://10.10.0.11:6443|server: https://34.124.248.110:6443|' /home/wizard/.kube/config
sed -i 's|server: https://10.10.0.11:6443|server: https://34.124.248.110:6443|' /home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts/admin.conf
export PATH="/home/wizard/.local/bin:$PATH"
kubectl get nodes
kubectl get pods -A | head -15
