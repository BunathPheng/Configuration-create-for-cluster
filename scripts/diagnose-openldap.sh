#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
kubectl -n ldap get pods -o wide
echo "--- DESCRIBE ---"
kubectl -n ldap describe pod -l app.kubernetes.io/name=openldap | tail -100
echo "--- LOGS ---"
kubectl -n ldap logs -l app.kubernetes.io/name=openldap --tail=100 || true
echo "--- EVENTS ---"
kubectl -n ldap get events --sort-by=.lastTimestamp | tail -30
