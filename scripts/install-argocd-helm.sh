#!/usr/bin/env bash
set -eu
export PATH="/home/wizard/.local/bin:$PATH"

# Install Helm locally if missing
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  mkdir -p /home/wizard/.local/bin
  [ -f /usr/local/bin/helm ] && cp /usr/local/bin/helm /home/wizard/.local/bin/helm || true
fi

helm version --short

# ArgoCD via official Helm chart
ARGOCD_CHART_VERSION="7.7.11"
ARGOCD_APP_VERSION="v2.13.3"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

cat > /tmp/argocd-values.yaml <<'EOF'
# Lab / single-worker cluster sizing
global:
  domain: argocd.example.com

server:
  service:
    type: LoadBalancer
  # Lab only: allow HTTP access without ingress TLS setup yet
  insecure: true

configs:
  params:
    server.insecure: true

controller:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

repoServer:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi

applicationSet:
  enabled: true
EOF

echo "=== Installing ArgoCD Helm chart ${ARGOCD_CHART_VERSION} ==="
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "${ARGOCD_CHART_VERSION}" \
  --values /tmp/argocd-values.yaml \
  --wait --timeout 10m

echo "=== ArgoCD server ==="
kubectl get svc -n argocd argocd-server
kubectl get pods -n argocd

echo "=== External URL ==="
IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ArgoCD UI: http://${IP}"

echo "=== Login ==="
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
