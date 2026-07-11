# Kubernetes Cluster Rebuild with Kubespray — Full Documentation

**Date:** 2026-07-11
**Machine:** Windows + WSL2 (Ubuntu 24.04)
**Kubespray version:** v2.31.0 (pinned tag)
**Status:** Deployment environment ready. Waiting on real servers.

---

## 1. Purpose

A production Kubernetes cluster originally deployed with Kubespray was lost when
its cloud instances expired. This project rebuilds the cluster from
configuration-as-code instead of manual installation.

Recovery principle: **we are not restoring the old cluster — we are rebuilding an
identical cluster and re-converging state from Git.**

- Recoverable from Git: cluster topology, Kubernetes settings, Helm values, app manifests
- NOT recoverable from Git: etcd data, PersistentVolume data, in-cluster secrets
  (these require object-storage backups: etcd snapshots, Velero, Vault snapshots)

---

## 2. What has been set up on this machine

All work lives in WSL Ubuntu because Ansible does not run natively on Windows.
Windows access path for all files: `\\wsl.localhost\Ubuntu\home\wizard\k8s-recovery`

| Item | Location (inside WSL) | Status |
|---|---|---|
| Kubespray repo, pinned `v2.31.0` | `~/k8s-recovery/kubespray` | Done |
| Cluster inventory | `~/k8s-recovery/kubespray/inventory/mycluster/inventory.ini` | Done (placeholder IPs) |
| Cluster variables (group_vars) | `~/k8s-recovery/kubespray/inventory/mycluster/group_vars/` | Done |
| Python venv + Ansible 2.18.18 | `~/k8s-recovery/kubespray/venv` | Done |
| SSH deploy keypair | `~/.ssh/k8s-deploy` (+ `.pub`) | Done |
| Syntax + inventory validation | `cluster.yml --syntax-check`, `ansible-inventory --graph` | Passed |

Folder structure:

```
~/k8s-recovery/
├── DOCUMENTATION.md          <- this file
├── NEXT-STEPS.md             <- short action checklist
└── kubespray/                <- git checkout, tag v2.31.0
    ├── cluster.yml           <- main deployment playbook
    ├── requirements.txt      <- pinned Ansible dependencies (installed)
    ├── venv/                 <- Python virtualenv with Ansible 2.18.18
    └── inventory/mycluster/
        ├── inventory.ini     <- node definitions (EDIT IPs HERE)
        └── group_vars/
            ├── all/          <- OS/etcd/cloud settings
            └── k8s_cluster/
                ├── k8s-cluster.yml    <- version, CNI, CIDRs, kube-proxy
                ├── addons.yml         <- helm, metrics-server, local-path
                └── k8s-net-calico.yml <- Calico settings
```

---

## 3. Cluster design

Topology: HA with stacked etcd (etcd colocated on control-plane nodes).

| Hostname | Role | Placeholder IP | Recommended size |
|---|---|---|---|
| k8s-cp-1 | control plane + etcd1 | 10.10.0.11 | 4 vCPU / 8 GB / 100 GB SSD |
| k8s-cp-2 | control plane + etcd2 | 10.10.0.12 | 4 vCPU / 8 GB / 100 GB SSD |
| k8s-cp-3 | control plane + etcd3 | 10.10.0.13 | 4 vCPU / 8 GB / 100 GB SSD |
| k8s-worker-1 | worker | 10.10.0.21 | 8 vCPU / 16 GB / 100 GB+ |
| k8s-worker-2 | worker | 10.10.0.22 | 8 vCPU / 16 GB / 100 GB+ |
| k8s-worker-3 | worker | 10.10.0.23 | 8 vCPU / 16 GB / 100 GB+ |

Three etcd members = quorum survives one node failure. Never use an even count.

OS requirement: Ubuntu 22.04/24.04 (or another distro supported by Kubespray
v2.31), swap off, unique hostnames, time sync enabled, SSD for etcd (fsync < 10ms).

Network requirements:
- All nodes on one L3-reachable subnet; allow all traffic between nodes
  (or at minimum: 6443, 2379-2380, 10250, 10257, 10259, 30000-32767/tcp, 179/tcp, 4789/udp)
- Pod CIDR `10.233.64.0/18` and Service CIDR `10.233.0.0/18` must NOT overlap the VPC

### Inventory file (as configured)

```ini
[kube_control_plane]
k8s-cp-1 ansible_host=10.10.0.11 ip=10.10.0.11 etcd_member_name=etcd1
k8s-cp-2 ansible_host=10.10.0.12 ip=10.10.0.12 etcd_member_name=etcd2
k8s-cp-3 ansible_host=10.10.0.13 ip=10.10.0.13 etcd_member_name=etcd3

[etcd:children]
kube_control_plane

[kube_node]
k8s-worker-1 ansible_host=10.10.0.21 ip=10.10.0.21
k8s-worker-2 ansible_host=10.10.0.22 ip=10.10.0.22
k8s-worker-3 ansible_host=10.10.0.23 ip=10.10.0.23

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/k8s-deploy
ansible_become=true
```

Notes:
- `ansible_host` = SSH address; `ip` = private bind address for kubelet/etcd
- In Kubespray v2.31 the `k8s_cluster` group is computed automatically from
  `kube_control_plane` + `kube_node`; it no longer needs to be declared
- Keep hostnames stable across rebuilds so nodeSelectors/affinity keep working

### Key variables configured (group_vars)

`k8s_cluster/k8s-cluster.yml`:

| Setting | Value | Why |
|---|---|---|
| `kube_network_plugin` | `calico` | default CNI; keep the same CNI as the original cluster |
| `kube_service_addresses` | `10.233.0.0/18` | must match original (firewall rules, peering) |
| `kube_pods_subnet` | `10.233.64.0/18` | must match original |
| `kube_proxy_mode` | `ipvs` | better at scale than iptables |
| `container_manager` | `containerd` | only supported runtime |
| `enable_nodelocaldns` | `true` | node-local DNS cache |
| `kubeconfig_localhost` | `true` (changed) | writes admin.conf to `inventory/mycluster/artifacts/` |

`k8s_cluster/addons.yml` (changed from defaults):

| Setting | Value | Why |
|---|---|---|
| `helm_enabled` | `true` | helm binary on control-plane nodes |
| `metrics_server_enabled` | `true` | `kubectl top`, HPA support |
| `metrics_server_kubelet_insecure_tls` | `true` | required with default kubelet certs |
| `local_path_provisioner_enabled` | `true` | default StorageClass for simple PVCs |

Ingress-nginx and cert-manager are intentionally left DISABLED in Kubespray —
in a GitOps setup ArgoCD should own them (single source of truth).

### SSH deploy key

- Private key: `~/.ssh/k8s-deploy` (WSL) — never leaves this machine
- Public key (add to every server's `~/.ssh/authorized_keys` or cloud-init):

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFhlEN/ljFkoh0EGz++fDwyzcL5QrnptXUxzWPByTEy5 kubespray-deploy
```

---

## 4. Why the Kubespray version is pinned

- Each Kubespray tag supports a narrow Kubernetes version range; mixing fails
- Variable names change between releases; group_vars are only valid for their tag
- `master` branch is not supported for production; tags are
- DR rule: rebuild with the pinned tag first, validate, upgrade later as a
  separate change via `upgrade-cluster.yml`

---

## 5. How to deploy (once servers exist)

Step 1 — edit the inventory with real IPs:

```bash
wsl
nano ~/k8s-recovery/kubespray/inventory/mycluster/inventory.ini
# replace 10.10.0.x with real IPs; set ansible_user to the image's user
```

Step 2 — verify SSH connectivity to all 6 nodes:

```bash
cd ~/k8s-recovery/kubespray
source venv/bin/activate
ansible -i inventory/mycluster/inventory.ini all -m ping   # all must return "pong"
```

Step 3 — deploy (30–45 minutes, idempotent — re-run on transient failures):

```bash
ansible-playbook -i inventory/mycluster/inventory.ini -b cluster.yml
```

Step 4 — use the cluster:

```bash
export KUBECONFIG=$PWD/inventory/mycluster/artifacts/admin.conf
kubectl get nodes
```

### What cluster.yml does internally

1. `bootstrap-os` — python, swap off, hostname
2. `preinstall` — kernel modules (br_netfilter, overlay), sysctls, /etc/hosts
3. `container-engine` — containerd + runc, systemd cgroups
4. `download` — pinned binaries and images (kubeadm, kubelet, etcdctl, CNI)
5. `etcd` — generates CA + per-member certs, renders systemd units with
   `ETCD_INITIAL_CLUSTER`, starts members, Raft leader election forms quorum
6. `control-plane` — kubeadm init on first node (generates cluster CA,
   static pod manifests in /etc/kubernetes/manifests), others join with
   `kubeadm join --control-plane`
7. `node` — workers run `kubeadm join` with bootstrap token; kubelet TLS
   bootstrap registers each Node
8. `network_plugin` — applies Calico; nodes flip NotReady -> Ready
9. `kubernetes-apps` — CoreDNS, nodelocaldns, metrics-server, addons

---

## 6. Validation checklist (run after deploy)

```bash
kubectl cluster-info                 # API server up
kubectl get nodes -o wide            # 6 nodes, all Ready
kubectl get pods -A                  # all Running/Completed

# etcd health (on a control-plane node)
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://<cp1>:2379,https://<cp2>:2379,https://<cp3>:2379 \
  --cacert=/etc/ssl/etcd/ssl/ca.pem \
  --cert=/etc/ssl/etcd/ssl/node-k8s-cp-1.pem \
  --key=/etc/ssl/etcd/ssl/node-k8s-cp-1-key.pem \
  endpoint health --cluster          # 3x healthy

# cross-node pod networking + DNS
kubectl create deploy nettest --image=nicolaka/netshoot --replicas=3 -- sleep infinity
kubectl exec deploy/nettest -- nslookup kubernetes.default.svc.cluster.local
kubectl delete deploy nettest

kubectl top nodes                    # metrics-server working
```

---

## 7. Platform + application recovery (after cluster is validated)

Install only ArgoCD by hand; everything else re-converges from Git:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.3/manifests/install.yaml

# re-add Git repo credentials (old in-cluster secrets are gone)
argocd repo add https://git.example.com/platform/k8s-apps.git --username <u> --password <token>

# apply the root app-of-apps -> ingress, cert-manager, Vault, monitoring, apps
kubectl apply -f root-app.yaml
```

Recovery flow: Git repo -> ArgoCD -> Helm charts -> Kubernetes applications.

Secrets caveat: Vault/OpenBao data returns only if you have Raft snapshots or
external storage. Sealed Secrets require the backed-up controller private key.
PersistentVolume data requires Velero/database backups — Git never contains data.

---

## 8. What changes vs. what stays the same in a rebuild

| Component | Keep | Change |
|---|---|---|
| Kubernetes version | pinned in group_vars | — |
| CNI + Pod/Service CIDRs | identical | — |
| Helm charts/values, manifests | from Git | — |
| Hostnames / node roles | identical | — |
| Server IPs | — | new -> update inventory, LB, DNS, firewall |
| Cluster CA / all TLS certs | — | regenerated -> ALL old kubeconfigs invalid |
| etcd data | — | new empty etcd; state rebuilt by ArgoCD |
| ServiceAccount tokens | — | new; external integrations must re-auth |
| PV data | only if externally backed | local-disk PVs are gone |
| Ingress/LB external IPs | — | new -> update DNS records |

---

## 9. Disaster recovery runbook (summary)

- **Day 0 — failure:** declare incident, freeze GitOps repo, inventory surviving
  assets (Git, object-storage backups, DNS control)
- **Day 1 — provision:** create 6 VMs, set hostnames, distribute deploy key,
  open firewall, update inventory IPs, `ansible all -m ping` green
- **Day 2 — Kubespray:** run `cluster.yml`, full validation suite, update API
  DNS, redistribute kubeconfigs (new CA)
- **Day 3 — restore:** ArgoCD -> root app -> platform components -> Vault
  snapshot restore -> ExternalSecrets sync -> Velero/DB restores -> app DNS ->
  end-to-end verification -> unfreeze Git, post-mortem
- **Week 1 — hardening:** automate etcd/Vault snapshots to object storage,
  alert on instance expiry, quarterly rebuild game-day in staging

---

## 10. Known constraints on this machine

- `d:\configuration create cluster` is read-only for the user account
  (Administrators only) — all files therefore live in WSL
- Docker is not installed on Windows (not needed; venv approach used instead)
- WSL networking fell back to VirtioProxy mode (warning only; git clone and
  package installs worked fine)
