#!/usr/bin/env bash
# Deploy OpenLDAP + configure Argo CD embedded DEX + RBAC
# Flow: User -> Argo CD -> DEX (OIDC) -> OpenLDAP (LDAP) -> groups -> Argo CD RBAC
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LDAP_DIR="${ROOT}/platform/openldap"
ARGO_DIR="${ROOT}/platform/argocd"

echo "=== 1) Deploy OpenLDAP (directory = source of users/groups) ==="
kubectl apply -f "${LDAP_DIR}/namespace.yaml"
kubectl apply -f "${LDAP_DIR}/secret.yaml"
kubectl apply -f "${LDAP_DIR}/deployment.yaml"

echo "Waiting for OpenLDAP..."
kubectl -n ldap rollout status deployment/openldap --timeout=180s

echo "=== 1b) Seed users/groups into OpenLDAP ==="
# Recreate seed job each run for idempotent lab resets
kubectl -n ldap delete job openldap-seed --ignore-not-found
kubectl apply -f "${LDAP_DIR}/seed-job.yaml"
kubectl -n ldap wait --for=condition=complete job/openldap-seed --timeout=180s
kubectl -n ldap logs job/openldap-seed || true

echo "=== 2) Store DEX LDAP bind password in argocd-secret ==="
BIND_PW="$(kubectl -n ldap get secret openldap-admin -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d)"
kubectl -n argocd patch secret argocd-secret --type merge -p \
  "{\"stringData\":{\"dex.ldap.bindPW\":\"${BIND_PW}\"}}"

echo "=== 3) Configure DEX LDAP connector in argocd-cm ==="
DEX_FILE="$(mktemp)"
PATCH_FILE="$(mktemp)"
cat >"${DEX_FILE}" <<'EOF'
logger:
  level: info
  format: json
connectors:
  - type: ldap
    id: openldap
    name: OpenLDAP
    config:
      host: openldap.ldap.svc.cluster.local:389
      insecureNoSSL: true
      insecureSkipVerify: true
      bindDN: cn=admin,dc=smartops,dc=local
      bindPW: $dex.ldap.bindPW
      usernamePrompt: OpenLDAP Username
      userSearch:
        baseDN: ou=people,dc=smartops,dc=local
        filter: "(objectClass=inetOrgPerson)"
        username: uid
        idAttr: uid
        emailAttr: mail
        nameAttr: cn
      groupSearch:
        baseDN: ou=groups,dc=smartops,dc=local
        filter: "(objectClass=groupOfNames)"
        userMatchers:
          - userAttr: DN
            groupAttr: member
        nameAttr: cn
EOF

python3 - <<PY >"${PATCH_FILE}"
import json, subprocess
dex = open("${DEX_FILE}").read()
cm = json.loads(subprocess.check_output(["kubectl", "-n", "argocd", "get", "cm", "argocd-cm", "-o", "json"]))
data = cm.get("data") or {}
data["url"] = "https://argocd.smartops.space"
data["admin.enabled"] = "true"
data["dex.config"] = dex
print(json.dumps({"data": data}))
PY

kubectl -n argocd patch cm argocd-cm --type merge --patch-file "${PATCH_FILE}"
rm -f "${DEX_FILE}" "${PATCH_FILE}"

echo "=== 4) Apply Argo CD RBAC (authorization from LDAP groups) ==="
kubectl apply -f "${ARGO_DIR}/rbac-cm.yaml"

echo "=== 5) Restart Argo CD server + DEX to reload config ==="
kubectl -n argocd rollout restart deployment/argocd-server deployment/argocd-dex-server
kubectl -n argocd rollout status deployment/argocd-dex-server --timeout=180s
kubectl -n argocd rollout status deployment/argocd-server --timeout=180s

echo
echo "=== Done ==="
echo "Login URL : https://argocd.smartops.space/"
echo "Button    : LOG IN VIA OPENLDAP"
echo
echo "Test users (OpenLDAP):"
echo "  alice   / AlicePass123!   -> group argocd-admins   -> role:admin"
echo "  bob     / BobPass123!     -> group argocd-readonly -> role:readonly"
echo "  charlie / CharliePass123! -> no group              -> login ok, no RBAC"
