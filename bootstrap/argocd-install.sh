#!/usr/bin/env bash
set -euo pipefail
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer
