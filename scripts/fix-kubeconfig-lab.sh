#!/usr/bin/env bash
set -eu
export PATH="/home/wizard/.local/bin:$PATH"

# Use fetched admin.conf as base
CFG=/home/wizard/k8s-recovery/kubespray/inventory/mycluster/artifacts/admin.conf
cp "$CFG" /home/wizard/.kube/config
chmod 600 /home/wizard/.kube/config

# Point to public IP and skip TLS verify (lab: cert has no public IP in SAN)
kubectl config set-cluster cluster.local \
  --server=https://34.124.248.110:6443 \
  --insecure-skip-tls-verify=true

kubectl config use-context kubernetes-admin@cluster.local
kubectl get nodes
