#!/usr/bin/env bash
set -eu
cd /home/wizard/k8s-recovery/kubespray
source venv/bin/activate
export ANSIBLE_HOST_KEY_CHECKING=False

echo "=== Current node status ==="
ansible -i inventory/mycluster/inventory.ini k8s-cp-1 -b -m command \
  -a "/usr/local/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide" \
  2>/dev/null | tail -6

echo "=== Re-running cluster.yml to completion ==="
ansible-playbook -i inventory/mycluster/inventory.ini -b cluster.yml \
  > /tmp/kubespray-deploy3.log 2>&1 || true

echo "=== PLAY RECAP ==="
grep -A6 "PLAY RECAP" /tmp/kubespray-deploy3.log | head -8

echo "=== Final node status ==="
ansible -i inventory/mycluster/inventory.ini k8s-cp-1 -b -m command \
  -a "/usr/local/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide" \
  2>/dev/null | tail -6

echo "=== System pods ==="
ansible -i inventory/mycluster/inventory.ini k8s-cp-1 -b -m command \
  -a "/usr/local/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A" \
  2>/dev/null | tail -25
