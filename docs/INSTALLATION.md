## Installation Guide

This guide describes how to install and run the platform locally and on servers. It evolves with the project; always consult the latest version in the repo.

### 1) Prerequisites

- macOS/Linux workstation or a cloud VM
- Docker
- kubectl
- k3d (for local clusters)
- helm
- make

Optional:

- k9s for cluster inspection

Verify tools:

```bash
docker --version && kubectl version --client && k3d version && helm version && make -v
```

### 2) Local Development (mini-prod)

Creates a local k3d cluster, installs Argo CD, and applies the dev-local overlay (MinIO + Supabase + helpers).

Steps:

1. Clone repo and enter directory

```bash
git clone https://github.com/raresum-com/platform.git
cd platform
```

2. Bootstrap local environment

```bash
make dev
```

3. Open UIs and ports (each in its own terminal)

```bash
# Argo CD (self‑signed TLS). Login user: admin
make argo-ui
# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

# MinIO Console / API
make minio-ui
make minio-api

# Supabase Studio (NodePort is preferred for stability)
make supabase-ui-nodeport   # http://localhost:31333
# Optional port-forward helper (may be flaky if kubectl version skew exists)
make supabase-ui            # http://localhost:3333
```

Default local credentials:

- MinIO: user `minioadmin`, password `minioadmin123`, bucket `dev-local`
- Supabase DB: `supabase_admin` / `supabase_pass`
- JWT secrets are placeholder values in dev-local; do not reuse in real environments.

Argo CD login:

- Username: `admin`
- Password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
  ```

Troubleshooting (local):

- Kubectl version skew can break port-forward. Prefer NodePorts.
  ```bash
  make check-kubectl-skew
  # If skew > 1 minor version, use NodePort targets or align versions
  ```
- Ports busy: `make stop-ports`
- Supabase Storage check via gateway (service role):
  ```bash
  SR=$(kubectl -n supabase get secret supabase-jwt -o jsonpath='{.data.serviceRoleKey}' | base64 -d)
  curl -i -H "Authorization: Bearer $SR" http://localhost:31380/storage/v1/health
  ```

Cleanup:

```bash
make stop-ports
make k3d-delete
```

### 3) Server Installation (single node or small cluster)

Goal: identical stack on any server/cloud. Use your own Kubernetes (k3s/k3d on single node, managed K8s in cloud) and install Argo CD + root app.

1. Provision Kubernetes

- Single node: install k3s or k3d
- Managed: create cluster (DO, AKS, GKE), configure `kubectl` context

2. Install Argo CD

```bash
./bootstrap/argocd-install.sh
```

3. Apply Root Application pointing to the appropriate overlay

```bash
kubectl apply -f cluster/base/root-app.yaml
```

4. Switch overlay per environment

- For staging/production, point `cluster/base/root-app.yaml` to `cluster/overlays/<env>` and ensure required secrets exist.

Supabase Logs vs. Platform Logs:

- Dev-local: Supabase Studio Logs are disabled by default (analytics/vector off) to keep bootstrap light. Core services (DB/REST/Auth/Storage) still work.
- What you miss locally by keeping Supabase logs off:
  - Studio’s built-in request/query logs UI. You still have container logs via `kubectl logs` and DB logs inside Postgres.
- On servers: enable Supabase logs by turning on `analytics` and `vector` in the server overlay and pinning images. Alternatively (recommended for platform-wide observability), deploy a central stack (Loki/Tempo/Prometheus/Grafana) and ship application logs there. Supabase logs then become optional.

Example: enabling Supabase logs in a server overlay (sketch):

```yaml
# overlays/production/apps/supabase.yaml (excerpt)
spec:
  source:
    helm:
      values: |
        analytics:
          enabled: true
        vector:
          enabled: true
      parameters:
        - name: analytics.enabled
          value: "true"
        - name: vector.enabled
          value: "true"
```

Platform observability (recommended):

- Use an observability stack (Grafana LGTM) for server logs and metrics. Application pods (API, workers) ship logs to Loki; traces to Tempo. This covers server/API/Celery/runtime logs comprehensively beyond Supabase.

### 4) Secrets Management

- For dev-local, static placeholders are used to simplify bootstrapping.
- For staging/production, use sealed-secrets or a vault.
- We standardize on a single passphrase for sealed-secrets; request it when needed.

### 5) Troubleshooting

- Argo CD “OutOfSync” but Healthy: expected in dev-local (helpers live in overlay). Use Sync if upstream chart drift occurs.
- Supabase Storage:
  - Ensure MinIO service: `minio.tools.svc.cluster.local:9000`
  - If Studio Storage fails, verify the in‑cluster gateway:
    ```bash
    kubectl -n supabase get svc supabase-gateway
    kubectl -n supabase port-forward svc/supabase-gateway 8088:80
    SR=$(kubectl -n supabase get secret supabase-jwt -o jsonpath='{.data.serviceRoleKey}' | base64 -d)
    curl -i -H "Authorization: Bearer $SR" http://localhost:8088/storage/v1/bucket
    ```
- Supabase Logs page in Studio shows 500 "fetch failed":
  - Our dev-local overlay uses the Postgres-backed logs provider (no Logflare/ClickHouse).
  - Studio is configured with `NEXT_ANALYTICS_BACKEND_PROVIDER=postgres` and talks to
    `pg-meta` at `http://postgres-meta:8080` via in-cluster DNS.
  - Quick check:
    ```bash
    kubectl -n supabase get deploy postgres-meta
    kubectl -n supabase run tmp --rm -it --image=alpine/curl --restart=Never -- \
      sh -lc 'apk add --no-cache curl >/dev/null && curl -sf http://postgres-meta:8080/healthz && echo OK'
    ```
  - If you use NodePort instead of port-forwarding: Studio is exposed at `http://localhost:31333` and the internal
    gateway is at `http://supabase-gateway` (in-cluster). No external endpoint is needed for logs.
- Ports busy: run `make stop-ports` before re-running helpers.

### 6) Upgrading

- Update chart versions and overlays; commit and let Argo CD sync.
- For changes requiring secrets, update sealed secrets and re-apply.

### 7) Roadmap Hooks (subject to change)

- Observability stack (Prometheus/Grafana/Loki/Tempo/Alertmanager)
- Backup stack (pgBackRest + Velero)
- App services overlays (frontend, backend-api, backend-ai)
