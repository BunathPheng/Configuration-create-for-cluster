#!/usr/bin/env bash
set -eu
export PATH="/home/wizard/.local/bin:/usr/local/bin:$PATH"

echo "=== Fix GCP LB + Traefik (hostPort 80/443) ==="

cd /home/wizard/k8s-recovery/terraform
~/.local/bin/terraform apply -auto-approve \
  -var project_id=k8s-cluster-502109 \
  -var-file=lab.tfvars

INGRESS_IP=$(~/.local/bin/terraform output -raw ingress_ip)
echo "Ingress IP: ${INGRESS_IP}"

helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --values /home/wizard/k8s-recovery/platform/traefik/values.yaml \
  --wait --timeout 5m

kubectl apply -f /home/wizard/k8s-recovery/platform/traefik/argocd-ingressroute.yaml

echo "=== Waiting for Traefik + GCP health check (up to 3 min) ==="
for i in $(seq 1 18); do
  READY=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo false)
  CODE=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://${INGRESS_IP}/" 2>/dev/null || echo 000)
  echo "attempt $i: traefik_ready=${READY} lb_http=${CODE}"
  if [ "$READY" = "true" ] && [ "$CODE" != "000" ] && [ "$CODE" != "000n" ]; then
    echo "SUCCESS: http://${INGRESS_IP}/ returns HTTP ${CODE}"
    exit 0
  fi
  sleep 10
done

kubectl get pods -n traefik -o wide
echo "LB may need 2-5 more minutes for GCP health check. Try: http://${INGRESS_IP}/"
