#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

echo "=== Pods ==="
kubectl -n ldap get pods
kubectl -n argocd get pods -l 'app.kubernetes.io/name in (argocd-server,argocd-dex-server)'

echo
echo "=== DEX connector present? ==="
kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.dex\.config}' | head -40

echo
echo "=== RBAC ==="
kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}'; echo
kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.scopes}'; echo

echo
echo "=== LDAP user bind test (alice) ==="
kubectl -n ldap exec deploy/openldap -- \
  ldapwhoami -x -H ldap://localhost \
  -D 'uid=alice,ou=people,dc=smartops,dc=local' -w 'AlicePass123!'

echo
echo "=== DEX recent logs ==="
kubectl -n argocd logs deploy/argocd-dex-server --tail=40
