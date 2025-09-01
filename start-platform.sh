#!/bin/bash

echo "🚀 Starting RareSum Platform..."

# Navigate to platform directory
cd "$(dirname "$0")"

# Kill any existing port-forwards
echo "🧹 Cleaning up existing port-forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true
lsof -ti :8080 | xargs -r kill 2>/dev/null || true
lsof -ti :9090 | xargs -r kill 2>/dev/null || true

# Start the platform
echo "🏗️  Starting k3d cluster and applications..."
make up

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/minio -n tools
kubectl wait --for=condition=available --timeout=300s deployment/supabase-supabase-studio -n supabase

# Fix Studio URLs to prevent example.com CORS errors
echo "🔧 Fixing Supabase Studio URLs..."
./fix-studio-urls.sh > /dev/null 2>&1

# Start port-forwards
echo "🔗 Setting up port-forwards..."
kubectl port-forward -n argocd svc/argocd-server 8080:443 > /tmp/argocd.log 2>&1 &
ARGOCD_PID=$!

kubectl port-forward -n tools svc/minio 9090:9001 > /tmp/minio.log 2>&1 &
MINIO_PID=$!

# Wait a moment for port-forwards to establish
sleep 3

# Test connections
echo "🧪 Testing connections..."
if curl -k -s https://localhost:8080 | grep -q "Argo CD"; then
    echo "✅ Argo CD accessible at https://localhost:8080"
else
    echo "❌ Argo CD not accessible"
fi

if curl -s http://localhost:9090 | grep -q "MinIO"; then
    echo "✅ MinIO Console accessible at http://localhost:9090"
else
    echo "❌ MinIO Console not accessible"
fi

# Show credentials
echo ""
echo "🔑 Platform ready! Access details:"
make creds

echo ""
echo "📝 To stop port-forwards: pkill -f 'kubectl port-forward'"
echo "📝 Port-forward PIDs: ArgoCD=$ARGOCD_PID, MinIO=$MINIO_PID"
echo "📝 Logs: /tmp/argocd.log, /tmp/minio.log"
