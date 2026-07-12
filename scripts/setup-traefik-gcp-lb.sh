#!/usr/bin/env bash
set -eu
export PATH="/home/wizard/.local/bin:/usr/local/bin:$PATH"

echo "=== 1. Apply GCP Load Balancer (Terraform) ==="
cd /home/wizard/k8s-recovery/terraform
~/.local/bin/terraform apply -auto-approve \
  -var project_id=k8s-cluster-502109 \
  -var-file=lab.tfvars

INGRESS_IP=$(~/.local/bin/terraform output -raw ingress_ip)
echo "GCP Ingress IP: ${INGRESS_IP}"

echo "=== 2. Install Traefik (Helm) ==="
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update

kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --values /home/wizard/k8s-recovery/platform/traefik/values.yaml \
  --wait --timeout 5m

echo "=== 3. Route ArgoCD through Traefik ==="
kubectl apply -f /home/wizard/k8s-recovery/platform/traefik/argocd-ingressroute.yaml

echo "=== 4. Status ==="
kubectl get pods -n traefik -o wide
kubectl get ingressroute -n argocd

echo ""
echo "============================================"
echo " Entry point: http://${INGRESS_IP}"
echo " ArgoCD UI:   http://${INGRESS_IP}/"
echo " Login:       admin"
echo -n " Password:    "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(change if secret rotated)"
echo ""
echo "============================================"
