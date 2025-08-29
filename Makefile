# ===== Settings =====
SUPA_NS := supabase
MINIO_NS := tools

SUPABASE_STUDIO_LOCAL_PORT := 3333
SUPABASE_POD_TARGET        := 3000

SUPABASE_DB_LOCAL_PORT := 5432
SUPABASE_DB_TARGET     := 5432

MINIO_API_LOCAL_PORT := 9000
MINIO_API_TARGET     := 9000

MINIO_UI_LOCAL_PORT := 9090
MINIO_UI_TARGET     := 9001

# k3d cluster name
K3D_CLUSTER_NAME := raresum

# ===== Helpers =====
.PHONY: help
help:
	@echo "make list-supabase   # Supabase namespace'teki Service/Deploy/Pod'ları gösterir"
	@echo "make supabase-ui      # Supabase Studio -> http://localhost:$(SUPABASE_STUDIO_LOCAL_PORT)"
	@echo "make supabase-db      # Supabase Postgres -> localhost:$(SUPABASE_DB_LOCAL_PORT)"
	@echo "make minio-api        # MinIO S3 API -> http://localhost:$(MINIO_API_LOCAL_PORT)"
	@echo "make minio-ui         # MinIO Console -> http://localhost:$(MINIO_UI_LOCAL_PORT)"
	@echo "make stop-ports       # 3333,5432,9000,9090 port-forward süreçlerini kapat"
	@echo "make k3d-create       # k3d ile lokal cluster oluştur (platform dev)"
	@echo "make k3d-delete       # k3d cluster'ı sil"
	@echo "make argocd-install   # Argo CD'yi kur (helm)"
	@echo "make argo-ui          # Argo CD UI -> http://localhost:8080 (port-forward)"
	@echo "make apply-root       # Root Application'ı uygula (overlays/dev-local)"
	@echo "make dev              # k3d + Argo CD + Root App (mini-prod)"

.PHONY: list-supabase
list-supabase:
	kubectl -n $(SUPA_NS) get svc -o wide || true
	kubectl -n $(SUPA_NS) get deploy -o wide || true
	kubectl -n $(SUPA_NS) get pods -o wide || true

.PHONY: stop-ports
stop-ports:
	-@lsof -ti tcp:$(SUPABASE_STUDIO_LOCAL_PORT) | xargs -r kill
	-@lsof -ti tcp:$(SUPABASE_DB_LOCAL_PORT)     | xargs -r kill
	-@lsof -ti tcp:$(MINIO_API_LOCAL_PORT)       | xargs -r kill
	-@lsof -ti tcp:$(MINIO_UI_LOCAL_PORT)        | xargs -r kill

# -------- internal: service keşfi (label + aday isim) --------
svc_heuristic = SVC=$$(kubectl -n $(SUPA_NS) get svc -l '$(2)' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); if [ -z "$$SVC" ]; then for CAND in $(1); do kubectl -n $(SUPA_NS) get svc $$CAND >/dev/null 2>&1 && SVC=$$CAND && break; done; fi;

# ===== Port-forwards =====
.PHONY: supabase-ui
supabase-ui:
	@kubectl -n $(SUPA_NS) rollout status deploy/supabase-supabase-studio --timeout=90s || true; \
	SVC=$$(kubectl -n $(SUPA_NS) get svc supabase-supabase-studio -o name 2>/dev/null || true); \
	if [ -z "$$SVC" ]; then \
	  SVC=$$(kubectl -n $(SUPA_NS) get svc -l 'app.kubernetes.io/name=supabase-studio' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	fi; \
	if [ -n "$$SVC" ]; then \
	  SVCPORT=$$(kubectl -n $(SUPA_NS) get $$SVC -o jsonpath='{.spec.ports[0].port}'); \
	  echo "[OK] $$SVC -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT) (remote:$$SVCPORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward $$SVC $(SUPABASE_STUDIO_LOCAL_PORT):$$SVCPORT; \
	fi; \
	echo "[ERR] Studio service bulunamadı."; exit 1

.PHONY: supabase-db
supabase-db:
	@$(call svc_heuristic, supabase-supabase-db supabase-postgresql postgresql db, app.kubernetes.io/name=postgresql) \
	if [ -n "$$SVC" ]; then \
	  SVCPORT=$$(kubectl -n $(SUPA_NS) get svc $$SVC -o jsonpath='{.spec.ports[0].port}'); \
	  echo "[OK] svc/$$SVC -> localhost:$(SUPABASE_DB_LOCAL_PORT) (remote:$$SVCPORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward svc/$$SVC $(SUPABASE_DB_LOCAL_PORT):$$SVCPORT; \
	fi; \
	POD=$$(kubectl -n $(SUPA_NS) get pods -l 'app.kubernetes.io/name=postgresql' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
	  echo "[OK] pod/$$POD -> localhost:$(SUPABASE_DB_LOCAL_PORT) (remote:$(SUPABASE_DB_TARGET))"; \
	  exec kubectl -n $(SUPA_NS) port-forward pod/$$POD $(SUPABASE_DB_LOCAL_PORT):$(SUPABASE_DB_TARGET); \
	fi; \
	echo "[ERR] DB için service/pod bulunamadı."; exit 1

.PHONY: minio-api
minio-api:
	kubectl -n $(MINIO_NS) port-forward svc/minio $(MINIO_API_LOCAL_PORT):$(MINIO_API_TARGET)

.PHONY: minio-ui
minio-ui:
	kubectl -n $(MINIO_NS) port-forward svc/minio $(MINIO_UI_LOCAL_PORT):$(MINIO_UI_TARGET)

# ===== Dev bootstrap (k3d + Argo CD + Root App) =====
.PHONY: k3d-create
k3d-create:
	@which k3d >/dev/null || (echo "[ERR] k3d yüklü değil. bkz: https://k3d.io" && exit 1)
	@which kubectl >/dev/null || (echo "[ERR] kubectl yüklü değil." && exit 1)
	@echo "[INFO] k3d cluster oluşturuluyor: $(K3D_CLUSTER_NAME)"
	-@k3d cluster create $(K3D_CLUSTER_NAME) \
	  --agents 1 \
	  --port 80:80@loadbalancer \
	  --port 443:443@loadbalancer
	@kubectl cluster-info

.PHONY: k3d-delete
k3d-delete:
	@echo "[INFO] k3d cluster siliniyor: $(K3D_CLUSTER_NAME)"
	-@k3d cluster delete $(K3D_CLUSTER_NAME)

.PHONY: argocd-install
argocd-install:
	@which helm >/dev/null || (echo "[ERR] helm yüklü değil." && exit 1)
	@echo "[INFO] Argo CD kuruluyor"
	./bootstrap/argocd-install.sh
	@echo "[INFO] Argo CD pod'ları bekleniyor"
	@kubectl -n argocd rollout status deploy/argocd-server --timeout=180s || true

.PHONY: argo-ui
argo-ui:
	@echo "[INFO] Argo CD UI -> http://localhost:8080"
	kubectl -n argocd port-forward svc/argocd-server 8080:443

.PHONY: apply-root
apply-root:
	@echo "[INFO] Root Application uygulanıyor (cluster/base/root-app.yaml)"
	kubectl apply -f cluster/base/root-app.yaml
	@echo "[INFO] Argo CD senkronizasyonunu kontrol edin. (Applications)"

.PHONY: dev
dev: k3d-create argocd-install apply-root
	@echo "[OK] Mini-prod kuruldu. UI erişimleri:"
	@echo " - Argo CD: make argo-ui (8080)"
	@echo " - MinIO: make minio-ui (9090), make minio-api (9000)"
	@echo " - Supabase: make supabase-ui (3333), make supabase-db (5432)"