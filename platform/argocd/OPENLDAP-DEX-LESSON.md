# OpenLDAP + DEX + Argo CD — Lab Lesson (AD substitute)

## Mental model (with OpenLDAP instead of AD)

| Concept in lesson | What we use in this lab |
|---|---|
| Active Directory | **OpenLDAP** (directory that stores users/groups) |
| LDAP protocol | LDAP to OpenLDAP on port **389** (in-cluster) |
| DEX | Argo CD **embedded DEX** |
| Argo CD | Existing `argocd` Helm release |

```
User --HTTPS--> Argo CD --OIDC--> DEX --LDAP--> OpenLDAP
                         ^                         |
                         +------- identity/claims -+
                         then Argo CD RBAC decides access
```

Argo CD never talks LDAP directly. DEX is the translator.

Full production-style sequence diagrams: [PRODUCTION-SEQUENCE-FLOW.md](./PRODUCTION-SEQUENCE-FLOW.md)

## Directory layout (`dc=smartops,dc=local`)

```
dc=smartops,dc=local
├── ou=people
│   ├── uid=alice     (admin)
│   ├── uid=bob       (readonly)
│   └── uid=charlie   (no group)
└── ou=groups
    ├── cn=argocd-admins    → alice
    └── cn=argocd-readonly  → bob
```

## Deploy / reconfigure

```bash
bash scripts/setup-openldap-dex-argocd.sh
```

## Login tests

URL: https://argocd.smartops.space/

| User | Password | LDAP group | Argo CD role |
|---|---|---|---|
| alice | AlicePass123! | argocd-admins | role:admin |
| bob | BobPass123! | argocd-readonly | role:readonly |
| charlie | CharliePass123! | *(none)* | auth OK, no permissions |

## Troubleshooting map (same as AD lesson)

1. **Cannot log in** → DNS/TLS to Argo CD, DEX pod logs, OpenLDAP pod, bind DN/password, user filter
2. **DEX cannot reach directory** → `openldap.ldap.svc.cluster.local:389`, NetworkPolicy, bind credentials
3. **Login OK, no permissions** → groupSearch, claim `groups`, `argocd-rbac-cm` string match
4. **TLS/LDAPS errors** → lab uses `insecureNoSSL: true`; production should use LDAPS :636 + CA

```bash
# Directory contents
kubectl -n ldap exec deploy/openldap -- \
  ldapsearch -x -H ldap://localhost \
  -D 'cn=admin,dc=smartops,dc=local' -w 'AdminPass123!' \
  -b 'dc=smartops,dc=local'

# DEX logs
kubectl -n argocd logs deploy/argocd-dex-server -f

# Confirm config
kubectl -n argocd get cm argocd-cm -o yaml | sed -n '/dex.config/,/^[^ ]/p'
kubectl -n argocd get cm argocd-rbac-cm -o yaml
```

## Production note

Replace OpenLDAP with real AD DCs later by changing only DEX connector host/bind/search bases to AD (`userPrincipalName`, `memberOf`, LDAPS 636). Argo CD OIDC + RBAC stay the same.
