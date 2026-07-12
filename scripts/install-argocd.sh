#!/usr/bin/env bash
set -eu
export PATH="/home/wizard/.local/bin:$PATH"

ARGOCD_VERSION="v2.13.3"

echo "=== Creating namespace ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "=== Installing ArgoCD ${ARGOCD_VERSION} ==="
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "=== Waiting for ArgoCD pods (up to 5 min) ==="
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd 2>/dev/null || true

kubectl wait --for=condition=ready --timeout=300s \
  pod -l app.kubernetes.io/name=argocd-server -n argocd 2>/dev/null || true

echo "=== Expose ArgoCD via LoadBalancer (public IP) ==="
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}' 2>/dev/null || \
kubectl patch svc argocd-server -n argocd --type merge -p '{"spec":{"type":"LoadBalancer"}}'

echo "=== Waiting for external IP ==="
for i in $(seq 1 30); do
  IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ -n "$IP" ]; then
    echo "ArgoCD URL: https://${IP}"
    break
  fi
  sleep 10
done

echo "=== Initial admin password ==="
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d; echo

echo "=== ArgoCD pods ==="
kubectl get pods -n argocd
kubectl get svc -n argocd argocd-server
