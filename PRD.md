# PRD — Self-Hosted, Portable, Compliant Deployment Platform

## 1) Purpose & Goals
Build a **fully self-hosted** deployment platform for a health-data application that is portable across laptops, on-prem servers, and multiple clouds (DigitalOcean/Azure/GCP) **without changing the stack**. Enforce **data residency** per region (e.g., TR data stays in TR; ES data stays in ES). Keep the system **sustainable**: simple dev experience, transparent CI/CD, built-in observability and backups.

---

## 2) High-Level Architecture

**Core app services**
- Frontend
- Backend API
- Backend AI

**Platform services**
- **Kubernetes** (K3s via k3d for local): orchestration  
- **Argo CD**: GitOps (sync from the platform repo)  
- **MinIO**: S3-compatible object storage (keeps files local to the region)  
- **Supabase (self-hosted)**: PostgreSQL + Auth + Realtime + Studio + Storage API (wired to MinIO)  
- **Observability**: Prometheus, Grafana, Loki, Tempo, Alertmanager  
- **Backups**: pgBackRest (WAL to MinIO), Velero (K8s objects + PVCs to MinIO)

---

## 3) Repositories & Versioning

### 3.1 Application repositories (polyrepo)
- `frontend`
- `backend-api`
- `backend-ai`

**Branches:** `staging`, `main`  
**CI pattern:**  
- `staging` → build container → push to GHCR with RC tag (e.g., `1.2.0-rc.3`)  
- `main` → promote the *same digest* to a stable tag (e.g., `1.2.0`)

### 3.2 Platform repository (single “platform” repo)
```
platform/
├─ infra/               # Terraform modules (DO/Azure/GCP/OnPrem)
├─ cluster/
│  ├─ base/             # Argo CD root app + shared building blocks
│  ├─ apps/             # frontend, backend-api, backend-ai manifests
│  ├─ data/             # supabase, minio
│  ├─ ops/              # observability, backups
│  └─ overlays/         # per-environment diffs
│     ├─ dev-local/
│     ├─ staging/
│     └─ production/
└─ bootstrap/           # install scripts (e.g., argocd install)
```
Argo CD “root app” points at `overlays/<env>`, which pulls in MinIO, Supabase, app workloads, and the observability stack.

---

## 4) Environments & Promotion Flow

### 4.1 Dev-local (on a laptop)
- `make dev` brings up k3d + Argo CD and applies the **dev-local** overlay.  
- You get a “mini-prod” on your machine: MinIO + Supabase + apps + observability.

### 4.2 Staging
- Commit to `staging` → CI builds & pushes to GHCR → bot opens a PR in the platform repo (staging overlay updates to the new tag) → merge → Argo CD deploys to the staging cluster.

### 4.3 Production
- Merge to `main` → CI promotes the image to a stable tag → bot opens a PR in the platform repo (production overlay) → merge → Argo CD deploys to prod. Rollback is a PR revert.

---

## 5) Observability & Backups

- **Prometheus/Grafana** for metrics & dashboards  
- **Loki** for logs (enable PII masking)  
- **Tempo** for distributed tracing across FE → API → DB  
- **Alertmanager** for alerts (Slack/Email)  
- **pgBackRest** for PostgreSQL WAL streaming to a MinIO bucket  
- **Velero** for Kubernetes objects + PVC snapshots to MinIO

Each cluster carries its own observability and backup stack to keep data in-region.

---

## 6) Data Governance & Residency

- **Strict locality:** app data (DB files, object storage, auth identities) must reside inside the country/region’s own Supabase+MinIO. No cross-region replication by default. (Optional: introduce per-table replication rules later.)  
- **Network boundaries:** cluster-internal traffic for DB/S3; expose only app ingress endpoints.  
- **Backups:** MinIO buckets scoped per region; off-region copies optional and encrypted.  
- **Access control:** use namespace-scoped credentials; rotate via CI secrets.

---

## 7) CI/CD Details (per app repo)

- **Build:** Dockerfile builds image; tag as `ghcr.io/<org>/<service>:<semver or rc>`  
- **Test:** unit/integration tests block promotion  
- **Push:** publish to GHCR  
- **Promote:** re-tag stable on `main` merge, never rebuild (promote by digest)  
- **Deploy:** open PR to the platform repo overlay with the new tag; merging triggers Argo CD sync. (Two-step flow mirrors staging→prod flow above.)

---

## 8) Platform Bootstrapping (per environment)

- **Bootstrap:** install Argo CD to the target cluster; apply `root` Application  
- **Sync:** Argo CD applies MinIO, Supabase, apps, observability from `overlays/<env>`  
- **Secrets:** provide environment-scoped secrets (DB creds, S3 creds, JWT) via sealed-secrets or vault  
- **Ingress:** expose FE/API endpoints; keep Supabase/MinIO admin UIs restricted (port-forward or VPN)

---

## 9) Operational Runbook (baseline)

- **Deploy:** merge the overlay PR → watch Argo CD health; each app has readiness probes.  
- **Rollback:** revert overlay PR; Argo CD restores previous version.  
- **DB backup:** verify pgBackRest jobs; test PITR quarterly.  
- **Cluster backup:** verify Velero schedules restore in a scratch cluster quarterly.  
- **Monitoring:** Grafana dashboards per environment; SLO alerts via Alertmanager.

---

## 10) Non-Goals (initial phase)

- Cross-region live data replication (can be added later with explicit policies).  
- Multi-cluster service mesh.  
- Blue/green or canary by default (start with simple Argo CD syncs; add progressive delivery later).

---

## 11) Risks & Mitigations

- **Registry throttling:** pin images and use GHCR; pre-warm images in clusters.  
- **Secrets drift:** manage via sealed-secrets/Argo CD and rotate with CI.  
- **Stateful services:** ensure StorageClasses exist; use MinIO + WAL for DB recovery.  
- **Compliance drift:** codify overlays per region (separate buckets/DBs/keys), audit via CI.

---

## 12) Acceptance Criteria

- **Portability:** the same platform repo can bootstrap **dev-local**, **staging**, and **production** clusters with no code changes.  
- **Residency:** each region’s data remains in its own Supabase + MinIO.  
- **Observability:** dashboards, logs, traces, and alerts present per environment.  
- **Backups:** scheduled DB WAL and Velero snapshots to regional MinIO.  
- **Promotion:** `staging → production` via platform-repo PRs; rollback via PR revert.

---

## 13) What’s Already Done & Next

**Done so far**: local tooling (Docker, k3d, kubectl, helm), local k3d cluster, Argo CD installed, MinIO running (console available locally).

**Next up**:  
1) Finalize the Supabase module & connect Storage API to MinIO  
2) Add observability stack (Prometheus/Grafana/Loki/Tempo/Alertmanager)  
3) Add manifests for the three app services  
4) Wire CI/CD in each app repo to open overlay PRs automatically  
5) Add backup modules (pgBackRest + Velero)  
6) Add Terraform for cloud clusters (staging/prod)

---

## 14) Glossary (quick)

- **Platform repo**: Single Git repo with cluster manifests (apps/data/ops) and overlays per environment.  
- **Overlay**: Kustomize directory (dev-local/staging/production) that applies env-specific diffs to the base.  
- **GitOps**: Manage runtime state by committing to Git; Argo CD syncs clusters accordingly.
