## Server Management Strategy

We will standardize on Ansible for server provisioning and lifecycle tasks to keep portability across macOS laptops, on-prem nodes, and cloud VMs.

### Goals
- One playbook to prepare hosts for running the platform
- Support k3s (single node) and managed K8s bootstrap paths
- Idempotent, auditable runs

### Scope (initial)
- Install dependencies (container runtime, kubectl, helm)
- Install k3s on single-node servers (optional)
- Configure `kubectl` context and access
- Install Argo CD via script and apply root app
- Set up MinIO/Supabase credentials via sealed-secrets (staging/prod)

### Structure
```
ansible/
  inventories/
    dev/
    staging/
    prod/
  group_vars/
  roles/
    common/
    k3s/
    argocd/
    platform_root/
  playbooks/
    site.yml
```

### Next Steps
- Add `ansible/` skeleton with `common` and `k3s` roles
- Parameterize environment (overlay) and secrets
- Provide a `Makefile` target to run Ansible for a given inventory

### Secrets and Passphrase
For sealed-secrets, we will use a consistent team passphrase. Please provide the passphrase when you want me to generate the initial sealed key material.

