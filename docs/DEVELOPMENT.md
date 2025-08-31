## Development Guidelines

Keep the PRD goals in mind: fully self-hosted, portable across environments, enforce data residency, and remain simple to operate.

### Repo Layout (current)

- `cluster/base`: Argo CD root app
- `cluster/apps`: shared app manifests (e.g., MinIO, Supabase)
- `cluster/overlays/dev-local`: local overlay
- `bootstrap`: install scripts (Argo CD)
- `Makefile`: common tasks and dev bootstrap

Planned structure per PRD:

- `cluster/apps`: frontend, backend-api, backend-ai, data (supabase, minio), ops (observability, backups)
- `cluster/overlays/{dev-local,staging,production}`
- `infra/` (Terraform) for cloud clusters

### Workflows

1. Local dev

```bash
make dev
# Argo, MinIO, Supabase access via helper targets
```

2. GitOps flow (staging → production)

- Each app repo builds images on `staging` and promotes on `main` by digest
- A bot updates this platform repo overlays via PRs
- Merged PR triggers Argo CD sync

3. Secrets

- Use placeholders in dev-local only
- Use sealed-secrets/vault for staging/production
- Maintain a consistent passphrase scheme; request passphrase from maintainer when needed

### Supabase (dev-local)

- Enabled: `db`, `rest`, `auth`, `storage`, `studio`
- Helpers: `postgres-meta` (schema browsing), `gateway` (routes /rest, /auth, /storage, /pg-meta)
- Disabled: `realtime`, `functions`, `analytics`, `vector`, `kong`
- Image tags pinned to avoid `:latest`
- Secrets via overlay:
  - `supabase-db` → username/password/database
  - `supabase-jwt` → `anonKey` / `serviceRoleKey` / `secret`
  - `supabase-s3` → MinIO access keys
- Storage → MinIO at `minio.tools.svc.cluster.local:9000`

Access helpers (Makefile):

- Argo: `make argo-ui` → https://localhost:8080 (admin / initial secret)
- MinIO: `make minio-ui` → http://localhost:9090
- Studio: `make supabase-ui` → http://localhost:3333 (preferred)
- Optional NodePorts: `make supabase-ui-nodeport`

Troubleshooting (local access):

- Port-forward fails with "Empty reply from server" or ECONNRESET:
  - Check version skew: `make check-kubectl-skew` (skew >1 can break port-forward)
  - Workarounds:
    - Downgrade kubectl to match cluster (e.g., 1.31) or recreate k3d with matching version
    - Use NodePort instead of port-forward: ensure k3d publishes 31333 (use `make k3d-create` from this repo)
    - Stop existing forwards: `make stop-ports` and retry `make supabase-ui`

Gateway (optional local testing):

```bash
kubectl -n supabase port-forward svc/supabase-gateway 8088:80
SR=$(kubectl -n supabase get secret supabase-jwt -o jsonpath='{.data.serviceRoleKey}' | base64 -d)
curl -i -H "Authorization: Bearer $SR" http://localhost:8088/storage/v1/bucket
```

### Troubleshooting

- OutOfSync in Argo CD (supabase): expected in dev-local; helpers are overlay-managed.
- Storage create-bucket fails:
  - Verify gateway forwarding works (curl above)
  - Check Storage logs: `kubectl -n supabase logs deploy/supabase-supabase-storage --tail=200`
- PgMeta errors in Studio:
  - Verify PgMeta: `kubectl -n supabase logs deploy/postgres-meta --tail=50`
- Ports busy: `make stop-ports`

### Definition of Done

- Manifests applied successfully via Argo CD
- Secrets wired appropriately for the target env
- Services reachable via port-forward/ingress
- Docs updated (INSTALLATION/DEVELOPMENT) when behavior changes
