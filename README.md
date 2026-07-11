# Configuration-create-for-cluster

Configuration-as-code to build (and rebuild after disaster) a production
Kubernetes cluster with **Kubespray v2.31.0** on **Google Cloud**.

If the cluster is ever lost, everything needed to recreate it is in this repo.

## Repository structure

```
├── KUBESPRAY_VERSION            # pinned Kubespray tag (v2.31.0)
├── DOCUMENTATION.md             # full technical documentation + DR runbook
├── NEXT-STEPS.md                # short action checklist
├── terraform/                   # GCP infrastructure (VPC, firewall, 6 VMs)
│   ├── main.tf                  #   also auto-generates the Ansible inventory
│   ├── variables.tf
│   └── outputs.tf
└── inventory/mycluster/         # Kubespray inventory + cluster variables
    ├── inventory.ini            # 3 control-plane (stacked etcd) + 3 workers
    └── group_vars/              # containerd, Calico, ipvs, helm, metrics-server
```

## Cluster design

- 3 control-plane nodes with stacked etcd (4 vCPU / 8 GB / 100 GB SSD)
- 3 worker nodes (8 vCPU / 16 GB / 100 GB SSD)
- Ubuntu 24.04, containerd, Calico CNI, kube-proxy ipvs
- Pod CIDR `10.233.64.0/18`, Service CIDR `10.233.0.0/18`, node subnet `10.10.0.0/24`

## How to (re)build the cluster

```bash
# 1. Get Kubespray at the pinned version
git clone --branch $(cat KUBESPRAY_VERSION) --depth 1 \
  https://github.com/kubernetes-sigs/kubespray.git
cp -r inventory/mycluster kubespray/inventory/mycluster

# 2. Install dependencies
cd kubespray
python3 -m venv venv && source venv/bin/activate
pip install -U pip && pip install -r requirements.txt

# 3. Provision servers on GCP (writes real IPs into inventory.ini automatically)
cd ../terraform
terraform init
terraform apply -var project_id=YOUR_GCP_PROJECT_ID
cp ../kubespray/inventory/mycluster/inventory.ini backup-check.ini  # optional

# 4. Deploy Kubernetes (~30-45 min)
cd ../kubespray
ansible -i inventory/mycluster/inventory.ini all -m ping
ansible-playbook -i inventory/mycluster/inventory.ini -b cluster.yml

# 5. Use the cluster
export KUBECONFIG=$PWD/inventory/mycluster/artifacts/admin.conf
kubectl get nodes
```

See `DOCUMENTATION.md` for validation steps, GitOps/ArgoCD restore flow,
and the full Day 0-3 disaster recovery runbook.
