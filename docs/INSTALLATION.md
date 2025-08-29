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
Creates a local k3d cluster, installs Argo CD, and applies the dev-local overlay (MinIO + Supabase now included).

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
3. Open UIs and ports
```bash
# Argo CD UI
make argo-ui
# MinIO Console and API
make minio-ui
make minio-api
# Supabase Studio and Postgres
make supabase-ui
make supabase-db
```

Default local credentials:
- MinIO: user `minioadmin`, password `minioadmin123`, bucket `dev-local`
- Supabase: Postgres `supabase_admin` / `supabase_pass`
- JWT secrets are placeholder values in dev-local; do not reuse in real environments.

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

### 4) Secrets Management
- For dev-local, static placeholders are used to simplify bootstrapping.
- For staging/production, use sealed-secrets or a vault.
- We will standardize on a single passphrase-based encryption for sealed secrets. Ask the maintainer to provide the passphrase when needed.

### 5) Troubleshooting
- Argo CD app out of sync: check Argo UI or `kubectl -n argocd get applications`.
- Image pulls throttled: add an image pull secret and reference it via `global.imagePullSecrets`.
- Supabase Storage to MinIO: ensure the `tools` namespace MinIO service is reachable at `minio.tools.svc.cluster.local:9000` and bucket exists.
- Ports busy: run `make stop-ports` before re-port-forwarding.

### 6) Upgrading
- Update chart versions and overlays; commit and let Argo CD sync.
- For changes requiring secrets, update sealed secrets and re-apply.

### 7) Roadmap Hooks (subject to change)
- Add observability stack (Prometheus/Grafana/Loki/Tempo/Alertmanager)
- Add backup stack (pgBackRest + Velero)
- Add app services overlays (frontend, backend-api, backend-ai)

