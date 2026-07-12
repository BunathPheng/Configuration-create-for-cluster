#!/usr/bin/env bash
set -eu
cd /home/wizard/k8s-recovery/kubespray
source venv/bin/activate
export ANSIBLE_HOST_KEY_CHECKING=False

echo "=== kubectl on control plane ==="
ansible -i inventory/mycluster/inventory.ini k8s-cp-1 -b -m shell \
  -a 'command -v kubectl || ls -la /usr/local/bin/kubectl /usr/bin/kubectl 2>/dev/null' \
  2>/dev/null | tail -4

echo "=== admin.conf on control plane ==="
ansible -i inventory/mycluster/inventory.ini k8s-cp-1 -b -m shell \
  -a 'test -f /etc/kubernetes/admin.conf && echo EXISTS || echo MISSING' \
  2>/dev/null | tail -2

echo "=== local artifacts ==="
ls -la inventory/mycluster/artifacts/ 2>/dev/null || echo "No local artifacts dir"
