# Kubespray cluster rebuild — ready to deploy

Everything below is already done on this machine (WSL Ubuntu):

- Kubespray cloned and pinned at tag **v2.31.0** -> `~/k8s-recovery/kubespray`
- Inventory created -> `kubespray/inventory/mycluster/inventory.ini` (3 control-plane + etcd, 3 workers)
- Group vars configured: containerd, Calico, ipvs, helm/metrics-server/local-path enabled, `kubeconfig_localhost: true`
- Python venv with Ansible 2.18 + all requirements -> `kubespray/venv`
- SSH deploy key generated -> `~/.ssh/k8s-deploy` (private) / `~/.ssh/k8s-deploy.pub` (public)
- Inventory graph and `cluster.yml --syntax-check` both pass

## What YOU must do before deploying

Option A — automatic with Terraform (GCP config ready in `~/k8s-recovery/terraform/`):

```bash
# one-time: authenticate gcloud (needs a GCP account + project with billing)
gcloud auth application-default login

cd ~/k8s-recovery/terraform
~/.local/bin/terraform init
~/.local/bin/terraform apply -var project_id=YOUR_GCP_PROJECT_ID
# creates VPC + firewall + 6 VMs, injects the SSH key,
# and WRITES inventory.ini automatically with the real IPs
```

Option B — manual:

1. Provision 6 servers (3x 4vCPU/8GB for control plane, 3x 8vCPU/16GB workers),
   Ubuntu 22.04/24.04, SSD disks, same subnet, all ports open between nodes.
2. Add the public key below to each server's deploy user (`~/.ssh/authorized_keys`
   or cloud-init `ssh_authorized_keys`):

   See `~/.ssh/k8s-deploy.pub`

3. Edit `kubespray/inventory/mycluster/inventory.ini`:
   - replace the placeholder 10.10.0.x IPs with the real server IPs
   - set `ansible_user` to your image's user (ubuntu, rocky, etc.)

## Deploy (run inside WSL)

```bash
cd ~/k8s-recovery/kubespray
source venv/bin/activate

# 1. connectivity check — all 6 nodes must return "pong"
ansible -i inventory/mycluster/inventory.ini all -m ping

# 2. deploy the cluster (~30-45 min)
ansible-playbook -i inventory/mycluster/inventory.ini -b cluster.yml

# 3. use the cluster
export KUBECONFIG=$PWD/inventory/mycluster/artifacts/admin.conf
kubectl get nodes
kubectl get pods -A
```

## After the cluster is up

Install ArgoCD, re-add Git repo credentials, apply the root app-of-apps,
then restore Vault/secrets and stateful data from backups.
(Full runbook is in the chat guide, sections 7-10.)
