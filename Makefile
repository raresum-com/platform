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
MINIO_UI_TARGET     := 9090

# ===== Helpers =====
.PHONY: help
help:
	@echo "make list-supabase   # Supabase namespace'teki Service/Deploy/Pod'ları gösterir"
	@echo "make supabase-ui      # Supabase Studio -> http://localhost:$(SUPABASE_STUDIO_LOCAL_PORT)"
	@echo "make supabase-db      # Supabase Postgres -> localhost:$(SUPABASE_DB_LOCAL_PORT)"
	@echo "make minio-api        # MinIO S3 API -> http://localhost:$(MINIO_API_LOCAL_PORT)"
	@echo "make minio-ui         # MinIO Console -> http://localhost:$(MINIO_UI_LOCAL_PORT)"
	@echo "make stop-ports       # 3333,5432,9000,9090 port-forward süreçlerini kapat"

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
	@$(call svc_heuristic, supabase-supabase-studio supabase-studio studio, app.kubernetes.io/name=supabase-studio) \
	if [ -n "$$SVC" ]; then \
	  SVCPORT=$$(kubectl -n $(SUPA_NS) get svc $$SVC -o jsonpath='{.spec.ports[0].port}'); \
	  echo "[OK] svc/$$SVC -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT) (remote:$$SVCPORT)"; \
	  exec kubectl -n $(SUPA_NS) port-forward svc/$$SVC $(SUPABASE_STUDIO_LOCAL_PORT):$$SVCPORT; \
	fi; \
	DEP=$$(kubectl -n $(SUPA_NS) get deploy -l 'app.kubernetes.io/name=supabase-studio' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$DEP" ]; then \
	  echo "[OK] deploy/$$DEP -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT) (remote:$(SUPABASE_POD_TARGET))"; \
	  exec kubectl -n $(SUPA_NS) port-forward deploy/$$DEP $(SUPABASE_STUDIO_LOCAL_PORT):$(SUPABASE_POD_TARGET); \
	fi; \
	POD=$$(kubectl -n $(SUPA_NS) get pods -l 'app.kubernetes.io/name=supabase-studio' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
	  echo "[OK] pod/$$POD -> localhost:$(SUPABASE_STUDIO_LOCAL_PORT) (remote:$(SUPABASE_POD_TARGET))"; \
	  exec kubectl -n $(SUPA_NS) port-forward pod/$$POD $(SUPABASE_STUDIO_LOCAL_PORT):$(SUPABASE_POD_TARGET); \
	fi; \
	echo "[ERR] Studio için service/deploy/pod bulunamadı."; exit 1

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
	kubectl -n $(MINIO_NS) port-forward svc/minio-console $(MINIO_UI_LOCAL_PORT):$(MINIO_UI_TARGET)