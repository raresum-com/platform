# ===== Settings =====
SUPA_NS := supabase
MINIO_NS := tools

SUPABASE_STUDIO_LOCAL_PORT := 3333
SUPABASE_STUDIO_TARGET     := 3000

SUPABASE_DB_LOCAL_PORT := 5432
SUPABASE_DB_TARGET     := 5432

MINIO_API_LOCAL_PORT := 9000
MINIO_API_TARGET     := 9000

MINIO_UI_LOCAL_PORT := 9090
MINIO_UI_TARGET     := 9090

# ===== Helpers =====
.PHONY: help
help:
	@echo "make list-supabase  # Supabase namespace içindeki Service/Pod/Deployment'ları gösterir"
	@echo "make supabase-ui     # Supabase Studio -> http://localhost:$(SUPABASE_STUDIO_LOCAL_PORT) (svc veya pod fallback)"
	@echo "make supabase-db     # Supabase Postgres -> localhost:$(SUPABASE_DB_LOCAL_PORT) (svc veya pod fallback)"
	@echo "make minio-api       # MinIO S3 API -> http://localhost:$(MINIO_API_LOCAL_PORT)"
	@echo "make minio-ui        # MinIO Console -> http://localhost:$(MINIO_UI_LOCAL_PORT)"
	@echo "make stop-ports      # 3333,5432,9000,9090 port-forward süreçlerini kapat"

.PHONY: list-supabase
list-supabase:
	kubectl -n $(SUPA_NS) get svc -o wide || true
	kubectl -n $(SUPA_NS) get deploy -o wide || true
	kubectl -n $(SUPA_NS) get pods -o wide || true

# Mac/Linux: belirli portları kullanan eski port-forward süreçlerini durdurur
.PHONY: stop-ports
stop-ports:
	-@lsof -ti tcp:$(SUPABASE_STUDIO_LOCAL_PORT) | xargs -r kill
	-@lsof -ti tcp:$(SUPABASE_DB_LOCAL_PORT)     | xargs -r kill
	-@lsof -ti tcp:$(MINIO_API_LOCAL_PORT)       | xargs -r kill
	-@lsof -ti tcp:$(MINIO_UI_LOCAL_PORT)        | xargs -r kill

# ===== Port-forwards =====
# Not: port-forward komutu çalıştığı terminali meşgul eder; açık kalması gerekir.

# Supabase Studio: önce Service bul, yoksa Deployment, yoksa Pod
.PHONY: supabase-ui
supabase-ui:
	@SVC=$$(kubectl -n $(SUPA_NS) get svc -l 'app.kubernetes.io/name=supabase-studio' \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$SVC" ]; then \
	  for CAND in supabase-supabase-studio supabase-studio studio; do \
	    kubectl -n $(SUPA_NS) get svc $$CAND >/dev/null 2>&1 && SVC=$$CAND && break; \
	  done; \
	fi; \
	if [ -n "$$SVC" ]; then \
	  echo "[OK] Port-forward (Service): svc/$$SVC -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward svc/$$SVC $(SUPABASE_STUDIO_LOCAL_PORT):$(SUPABASE_STUDIO_TARGET); \
	fi; \
	DEP=$$(kubectl -n $(SUPA_NS) get deploy -l 'app.kubernetes.io/name=supabase-studio' \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$DEP" ]; then \
	  for CAND in supabase-supabase-studio supabase-studio studio; do \
	    kubectl -n $(SUPA_NS) get deploy $$CAND >/dev/null 2>&1 && DEP=$$CAND && break; \
	  done; \
	fi; \
	if [ -n "$$DEP" ]; then \
	  echo "[OK] Port-forward (Deployment): deploy/$$DEP -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward deploy/$$DEP $(SUPABASE_STUDIO_LOCAL_PORT):$(SUPABASE_STUDIO_TARGET); \
	fi; \
	POD=$$(kubectl -n $(SUPA_NS) get pods -l 'app.kubernetes.io/name=supabase-studio' \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
	  POD=$$(kubectl -n $(SUPA_NS) get pods -o name | grep -m1 studio || true); \
	fi; \
	if [ -n "$$POD" ]; then \
	  echo "[OK] Port-forward (Pod): $$POD -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward $$POD $(SUPABASE_STUDIO_LOCAL_PORT):$(SUPABASE_STUDIO_TARGET); \
	fi; \
	echo "[ERR] Supabase Studio servisi/podu/deploy bulunamadı. 'make list-supabase' ile kontrol edin."; exit 1

# Supabase Postgres: önce Service bul, yoksa Pod
.PHONY: supabase-db
supabase-db:
	@SVC=$$(kubectl -n $(SUPA_NS) get svc -l 'app.kubernetes.io/name=postgresql' \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$SVC" ]; then \
	  for CAND in supabase-supabase-db supabase-postgresql postgresql db; do \
	    kubectl -n $(SUPA_NS) get svc $$CAND >/dev/null 2>&1 && SVC=$$CAND && break; \
	  done; \
	fi; \
	if [ -n "$$SVC" ]; then \
	  echo "[OK] Port-forward (Service): svc/$$SVC -> localhost:$(SUPABASE_DB_LOCAL_PORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward svc/$$SVC $(SUPABASE_DB_LOCAL_PORT):$(SUPABASE_DB_TARGET); \
	fi; \
	POD=$$(kubectl -n $(SUPA_NS) get pods -l 'app.kubernetes.io/name=postgresql' \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
	  POD=$$(kubectl -n $(SUPA_NS) get pods -o name | grep -m1 -E 'postgres|supabase-db' || true); \
	fi; \
	if [ -n "$$POD" ]; then \
	  echo "[OK] Port-forward (Pod): $$POD -> localhost:$(SUPABASE_DB_LOCAL_PORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward $$POD $(SUPABASE_DB_LOCAL_PORT):$(SUPABASE_DB_TARGET); \
	fi; \
	echo "[ERR] Supabase Postgres servisi/podu bulunamadı. 'make list-supabase' ile kontrol edin."; exit 1

.PHONY: minio-api
minio-api:
	kubectl -n $(MINIO_NS) port-forward svc/minio $(MINIO_API_LOCAL_PORT):$(MINIO_API_TARGET)

.PHONY: minio-ui
minio-ui:
	kubectl -n $(MINIO_NS) port-forward svc/minio-console $(MINIO_UI_LOCAL_PORT):$(MINIO_UI_TARGET)