#!/bin/bash

echo "🔧 Fixing Supabase Studio URLs to prevent example.com CORS errors..."

# Patch Studio deployment to use localhost URLs instead of example.com
kubectl patch deployment supabase-supabase-studio -n supabase --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env",
    "value": [
      {"name": "NEXT_ANALYTICS_BACKEND_PROVIDER", "value": "postgres"},
      {"name": "NEXT_PUBLIC_ENABLE_LOGS", "value": "true"},
      {"name": "STUDIO_DEFAULT_ORGANIZATION", "value": "Default Organization"},
      {"name": "STUDIO_DEFAULT_PROJECT", "value": "Default Project"},
      {"name": "STUDIO_PORT", "value": "3000"},
      {"name": "SUPABASE_PUBLIC_URL", "value": "http://localhost:31380"},
      {"name": "STUDIO_PG_META_URL", "value": "http://localhost:31380/pg-meta"},
      {"name": "SUPABASE_URL", "value": "http://localhost:31380"},
      {"name": "NEXT_PUBLIC_SUPABASE_URL", "value": "http://localhost:31380"},
      {"name": "SUPABASE_ANON_KEY", "valueFrom": {"secretKeyRef": {"key": "anonKey", "name": "supabase-jwt"}}},
      {"name": "SUPABASE_SERVICE_KEY", "valueFrom": {"secretKeyRef": {"key": "serviceRoleKey", "name": "supabase-jwt"}}}
    ]
  }
]'

echo "✅ Studio URLs fixed!"
echo "📝 Studio now uses http://localhost:31380 instead of example.com"
echo "🧪 Try uploading files in Supabase Studio - CORS errors should be resolved"
