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

# Supabase Studio NodePort (dev-local)
SUPABASE_NODEPORT := 31333

# ===== Helpers =====
.PHONY: help
help:
	@echo "make list-supabase   # Supabase namespace'teki Service/Deploy/Pod'ları gösterir"
	@echo "make supabase-ui      # Supabase Studio -> http://localhost:$(SUPABASE_STUDIO_LOCAL_PORT)"
	@echo "make supabase-ui-nodeport # Supabase Studio (NodePort) -> http://localhost:$(SUPABASE_NODEPORT)"
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
	@echo "make up               # Idempotent: start/create k3d + Argo CD + Root App"
	@echo "make creds            # Yerel erişim URL'leri ve kimlik bilgilerini yazdır"
	@echo "make minio-ui-up      # MinIO Console port-forward'ı arka planda başlat (9090->9001)"
	@echo "make minio-ui-down    # MinIO Console port-forward'ı durdur"

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

.PHONY: supabase-ui-nodeport
supabase-ui-nodeport:
	@URL=http://localhost:$(SUPABASE_NODEPORT); \
	echo "[OK] Supabase Studio (NodePort) -> $$URL"; \
	if command -v open >/dev/null 2>&1; then open $$URL; elif command -v xdg-open >/dev/null 2>&1; then xdg-open $$URL; else echo "Open $$URL in your browser"; fi

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
	kubectl -n $(MINIO_NS) port-forward --address 127.0.0.1 svc/minio $(MINIO_API_LOCAL_PORT):$(MINIO_API_TARGET)

.PHONY: minio-ui
minio-ui:
	kubectl -n $(MINIO_NS) port-forward --address 127.0.0.1 svc/minio $(MINIO_UI_LOCAL_PORT):$(MINIO_UI_TARGET)

.PHONY: minio-ui-up
minio-ui-up:
	@echo "[INFO] MinIO Console port-forward başlatılıyor (localhost:$(MINIO_UI_LOCAL_PORT) -> svc/minio:$(MINIO_UI_TARGET))";
	-@lsof -ti tcp:$(MINIO_UI_LOCAL_PORT) | xargs -r kill;
	nohup kubectl -n $(MINIO_NS) port-forward --address 127.0.0.1 svc/minio $(MINIO_UI_LOCAL_PORT):$(MINIO_UI_TARGET) >/tmp/minio-ui-pf.log 2>&1 & echo $$! > /tmp/minio-ui-pf.pid;
	@sleep 1; echo "[OK] Çalışıyor. Log: /tmp/minio-ui-pf.log PID: $$(cat /tmp/minio-ui-pf.pid)";

.PHONY: minio-ui-down
minio-ui-down:
	@echo "[INFO] MinIO Console port-forward sonlandırılıyor";
	-@if [ -f /tmp/minio-ui-pf.pid ]; then kill $$(cat /tmp/minio-ui-pf.pid) 2>/dev/null || true; rm -f /tmp/minio-ui-pf.pid; fi;
	-@lsof -ti tcp:$(MINIO_UI_LOCAL_PORT) | xargs -r kill;
	@echo "[OK] Durduruldu."

# ===== Dev bootstrap (k3d + Argo CD + Root App) =====
.PHONY: k3d-create
k3d-create:
	@which k3d >/dev/null || (echo "[ERR] k3d yüklü değil. bkz: https://k3d.io" && exit 1)
	@which kubectl >/dev/null || (echo "[ERR] kubectl yüklü değil." && exit 1)
	@echo "[INFO] k3d cluster oluşturuluyor: $(K3D_CLUSTER_NAME)"
	-@k3d cluster create $(K3D_CLUSTER_NAME) \
	  --agents 1 \
	  --port 80:80@loadbalancer \
	  --port 443:443@loadbalancer \
	  --port 31333:31333@server:0 \
	  --port 31380:31380@server:0 \
	  --port 31300:31300@server:0
	@kubectl cluster-info

.PHONY: check-kubectl-skew
check-kubectl-skew:
	@echo "[INFO] kubectl client/server versions (skew >1 may break port-forward):"
	@kubectl version || true

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

# ===== One-shot bootstrap & helper outputs =====
.PHONY: up
up:
	@which k3d >/dev/null || (echo "[ERR] k3d yüklü değil. bkz: https://k3d.io" && exit 1)
	@which kubectl >/dev/null || (echo "[ERR] kubectl yüklü değil." && exit 1)
	@which helm >/dev/null || (echo "[ERR] helm yüklü değil." && exit 1)
	@echo "[INFO] k3d cluster durumu kontrol ediliyor: $(K3D_CLUSTER_NAME)"
	@if k3d cluster list 2>/dev/null | tail -n +2 | awk '{print $$1}' | grep -qx '$(K3D_CLUSTER_NAME)'; then \
		echo "[INFO] Cluster mevcut. Başlatılıyor..."; \
		k3d cluster start $(K3D_CLUSTER_NAME) || true; \
	else \
		$(MAKE) k3d-create; \
	fi
	@$(MAKE) argocd-install
	@$(MAKE) apply-root
	@echo "[OK] Kurulum tamam. Hızlı erişim için: make creds"

.PHONY: creds
creds:
	@echo "[URL]  Argo CD:           https://localhost:8080"
	@echo "[URL]  Supabase Studio:   http://localhost:$(SUPABASE_NODEPORT)"
	@echo "[URL]  Supabase Gateway:  http://localhost:31380"
	@echo "[URL]  MinIO Console:     http://localhost:31900"
	@echo "[URL]  MinIO S3 API:      http://localhost:31901"
	@echo
	@echo "[CREDS] Argo CD: user=admin pass=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
	@echo
	@if kubectl -n $(MINIO_NS) get secret minio >/dev/null 2>&1; then \
		MU=$$(kubectl -n $(MINIO_NS) get secret minio -o jsonpath='{.data.root-user}' | base64 -d); \
		MP=$$(kubectl -n $(MINIO_NS) get secret minio -o jsonpath='{.data.root-password}' | base64 -d); \
		echo "[CREDS] MinIO:   user=$$MU pass=$$MP"; \
	else \
		echo "[CREDS] MinIO:   user=minioadmin pass=minioadmin123"; \
	fi
	@SDU=$$(kubectl -n $(SUPA_NS) get secret supabase-db -o jsonpath='{.data.username}' 2>/dev/null | base64 -d); \
	 SPD=$$(kubectl -n $(SUPA_NS) get secret supabase-db -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
	 SDB=$$(kubectl -n $(SUPA_NS) get secret supabase-db -o jsonpath='{.data.database}' 2>/dev/null | base64 -d); \
	 echo "[CREDS] SupaDB:  user=$$SDU pass=$$SPD db=$$SDB host=localhost port=$(SUPABASE_DB_LOCAL_PORT)";
	@ANON=$$(kubectl -n $(SUPA_NS) get secret supabase-jwt -o jsonpath='{.data.anonKey}' 2>/dev/null | base64 -d); \
	 SR=$$(kubectl -n $(SUPA_NS) get secret supabase-jwt -o jsonpath='{.data.serviceRoleKey}' 2>/dev/null | base64 -d); \
	 echo "[CREDS] SupaJWT: anonKey=$$ANON"; \
	 echo "[CREDS] SupaJWT: serviceRoleKey=$$SR";