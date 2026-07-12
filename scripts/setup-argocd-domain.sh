#!/usr/bin/env bash
set -eu
export PATH="/home/wizard/.local/bin:/usr/local/bin:$PATH"

INGRESS_IP=$(cd /home/wizard/k8s-recovery/terraform && ~/.local/bin/terraform output -raw ingress_ip)

echo "=== Upgrade Traefik (Let's Encrypt) ==="
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --values /home/wizard/k8s-recovery/platform/traefik/values.yaml \
  --wait --timeout 5m

echo "=== Apply ArgoCD IngressRoute for argocd.smartops.space ==="
kubectl apply -f /home/wizard/k8s-recovery/platform/traefik/argocd-ingressroute.yaml

echo "=== Set ArgoCD external URL ==="
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"url":"https://argocd.smartops.space"}}'

helm upgrade argocd argo/argo-cd -n argocd --reuse-values \
  --set global.domain=argocd.smartops.space \
  --set configs.cm.url=https://argocd.smartops.space \
  --timeout 5m

echo ""
echo "============================================"
echo " DNS REQUIRED (do this in your DNS provider):"
echo "   argocd.smartops.space  A  ${INGRESS_IP}"
echo ""
echo " After DNS propagates (~5-30 min):"
echo "   https://argocd.smartops.space/"
echo "   Username: admin"
echo -n "   Password: "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
echo "============================================"
