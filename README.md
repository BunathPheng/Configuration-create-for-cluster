# Configuration-create-for-cluster

Configuration-as-code to build (and rebuild after disaster) a production
Kubernetes cluster with **Kubespray v2.31.0** on **Google Cloud**.

If the cluster is ever lost, everything needed to recreate it is in this repo.

## Repository structure

```
├── KUBESPRAY_VERSION            # pinned Kubespray tag (v2.31.0)
├── DOCUMENTATION.md             # full technical documentation + DR runbook
├── NEXT-STEPS.md                # short action checklist
├── terraform/                   # GCP infrastructure (VPC, firewall, VMs, LB)
│   ├── main.tf                  #   also auto-generates the Ansible inventory
│   ├── loadbalancer.tf          #   GCP external LB + static IP for Traefik
│   ├── lab.tfvars               #   lab sizing for free-trial ($300 credit)
│   ├── variables.tf
│   └── outputs.tf
├── platform/
│   ├── traefik/                 # Traefik ingress + ArgoCD IngressRoute
│   ├── openldap/                # Lab directory (AD substitute) + seed users/groups
│   └── argocd/                  # DEX LDAP + RBAC lesson manifests
├── scripts/                     # setup helpers (ArgoCD, Traefik, OpenLDAP/DEX, etc.)
└── inventory/mycluster/         # Kubespray inventory + cluster variables
    ├── inventory.ini
    └── group_vars/
```

## Cluster design (lab)

- 3 control-plane nodes with stacked etcd + 1 worker (GCP free-trial quota)
- Ubuntu 24.04, containerd, Calico CNI, kube-proxy ipvs, Kubernetes v1.35.4
- Pod CIDR `10.233.64.0/18`, Service CIDR `10.233.0.0/18`, node subnet `10.10.0.0/24`

## Platform services (deployed)

| Service | URL | Install |
|---|---|---|
| **ArgoCD** | https://argocd.smartops.space/ | Helm (`scripts/install-argocd-helm.sh`) |
| **Traefik** | entry point on GCP LB | Helm (`platform/traefik/values.yaml`) |
| **GCP Load Balancer** | static IP via `terraform output ingress_ip` | `terraform/loadbalancer.tf` |
| **OpenLDAP + DEX** | Login via OpenLDAP on Argo CD | `scripts/setup-openldap-dex-argocd.sh` |

**Identity lab (no AD):** OpenLDAP stores users/groups → DEX speaks LDAP → Argo CD uses OIDC + RBAC.  
Lesson: `platform/argocd/OPENLDAP-DEX-LESSON.md` · Sequence flow: `platform/argocd/PRODUCTION-SEQUENCE-FLOW.md`

**Test logins:** `alice/AlicePass123!` (admin), `bob/BobPass123!` (readonly), `charlie/CharliePass123!` (no RBAC)

**DNS:** `argocd.smartops.space` → A record → GCP ingress IP (`terraform output ingress_ip`)

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

# 3. Provision servers + load balancer on GCP
cd ../terraform
terraform init
terraform apply -var project_id=YOUR_GCP_PROJECT_ID -var-file=lab.tfvars

# 4. Deploy Kubernetes (~30-45 min)
cd ../kubespray
ansible -i inventory/mycluster/inventory.ini all -m ping
ansible-playbook -i inventory/mycluster/inventory.ini -b cluster.yml

# 5. Install platform (Traefik + ArgoCD + domain)
bash ../scripts/setup-traefik-gcp-lb.sh
bash ../scripts/install-argocd-helm.sh
bash ../scripts/setup-argocd-domain.sh

# 6. Use the cluster
export KUBECONFIG=$HOME/.kube/config   # or fetch via scripts/fetch-kubeconfig.sh
kubectl get nodes
```

See `DOCUMENTATION.md` for validation steps, GitOps recovery flow,
and the full Day 0-3 disaster recovery runbook.
