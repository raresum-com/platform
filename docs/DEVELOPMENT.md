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
1) Local dev
```bash
make dev
# Argo, MinIO, Supabase access via helper targets
```

2) GitOps flow (staging → production)
- Each app repo builds images on `staging` and promotes on `main` by digest
- A bot updates this platform repo overlays via PRs
- Merged PR triggers Argo CD sync

3) Secrets
- Use placeholders in dev-local only
- Use sealed-secrets/vault for staging/production
- Maintain a consistent passphrase scheme; request passphrase from maintainer when needed

### Roadmap and Steps to Target
Near-term tasks aligning to PRD acceptance criteria:
- Observability stack: Prometheus, Grafana, Loki, Tempo, Alertmanager
- Backup stack: pgBackRest (WAL to MinIO), Velero (to MinIO)
- Application overlays: frontend, backend-api, backend-ai with health checks
- CI/CD bots in app repos to open overlay PRs
- Terraform modules for DO/Azure/GCP/On-Prem

### Conventions
- Kustomize overlays per env; keep base minimal
- Prefer Argo CD Applications per component (apps, data, ops)
- Namespaces:
  - `tools`: shared tooling (MinIO)
  - `supabase`: Supabase stack
  - `argocd`: Argo CD
- Resource requirements start small; scale via overlays
- Keep all defaults safe for dev-local; tighten for staging/prod

### Testing and Validation
- After changes, validate Argo CD sync and component health
- Use `kubectl -n <ns> get pods` and `k9s` for quick checks
- Use Makefile helpers for port-forwards

### Definition of Done
- Manifests applied successfully via Argo CD
- Secrets wired appropriately for the target env
- Services reachable via port-forward/ingress
- Docs updated (INSTALLATION/DEVELOPMENT) when behavior changes

