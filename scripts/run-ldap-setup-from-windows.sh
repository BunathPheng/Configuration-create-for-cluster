#!/usr/bin/env bash
set -euo pipefail
SRC=/mnt/c/Users/Bunath/Documents/Configuration-create-for-cluster
DST=/home/wizard/k8s-recovery
# Normalize CRLF from Windows checkout
find "$SRC/platform/openldap" "$SRC/platform/argocd" "$SRC/scripts" -type f \( -name '*.yaml' -o -name '*.sh' -o -name '*.md' \) -exec sed -i 's/\r$//' {} +
mkdir -p "$DST/platform" "$DST/scripts"
rm -rf "$DST/platform/openldap" "$DST/platform/argocd"
cp -a "$SRC/platform/openldap" "$DST/platform/"
cp -a "$SRC/platform/argocd" "$DST/platform/"
cp -a "$SRC/scripts/setup-openldap-dex-argocd.sh" "$DST/scripts/"
chmod +x "$DST/scripts/setup-openldap-dex-argocd.sh"
export PATH="$HOME/.local/bin:$PATH"
# Reset crashed OpenLDAP so new Deployment (no bootstrap mount) starts clean
kubectl -n ldap delete deploy openldap --ignore-not-found
kubectl -n ldap delete job openldap-seed --ignore-not-found
kubectl -n ldap delete cm openldap-bootstrap --ignore-not-found
bash "$DST/scripts/setup-openldap-dex-argocd.sh"
