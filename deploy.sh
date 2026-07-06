#!/usr/bin/env bash
# Automated Vercel deployment for credila-web-demo — no CLI, no Node, just curl.
#
# Usage:
#   VERCEL_TOKEN=xxxxx ./deploy.sh
#   # or save the token once to a gitignored file:
#   echo "xxxxx" > .vercel-token && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

# --- Resolve token (env var wins, else .vercel-token file) ---
if [ -z "${VERCEL_TOKEN:-}" ] && [ -f .vercel-token ]; then
  VERCEL_TOKEN="$(tr -d '[:space:]' < .vercel-token)"
fi
: "${VERCEL_TOKEN:?Provide a Vercel token via VERCEL_TOKEN env var or a .vercel-token file}"

PROJECT="${VERCEL_PROJECT:-credila-web-demo}"
API="https://api.vercel.com"
AUTH="Authorization: Bearer ${VERCEL_TOKEN}"

FILES=(index.html)

echo "→ Uploading files to Vercel..."
files_json=""
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "  ✗ missing $f"; exit 1; }
  sha=$(shasum -a 1 "$f" | awk '{print $1}')
  size=$(wc -c < "$f" | tr -d ' ')
  http=$(curl -s -o /tmp/vercel_upload.json -w '%{http_code}' -X POST "${API}/v2/files" \
    -H "$AUTH" -H "Content-Type: application/octet-stream" -H "x-vercel-digest: ${sha}" \
    --data-binary "@${f}")
  if [ "$http" != "200" ] && [ "$http" != "201" ]; then
    echo "  ✗ upload failed for $f (HTTP $http):"; cat /tmp/vercel_upload.json; echo; exit 1
  fi
  echo "  ✓ $f (${size} bytes, sha ${sha:0:8})"
  files_json="${files_json}{\"file\":\"${f}\",\"sha\":\"${sha}\",\"size\":${size}},"
done
files_json="[${files_json%,}]"

echo "→ Creating production deployment..."
payload="{\"name\":\"${PROJECT}\",\"files\":${files_json},\"target\":\"production\",\"projectSettings\":{\"framework\":null}}"
http=$(curl -s -o /tmp/vercel_deploy.json -w '%{http_code}' -X POST "${API}/v13/deployments" \
  -H "$AUTH" -H "Content-Type: application/json" -d "$payload")
if [ "$http" != "200" ] && [ "$http" != "201" ]; then
  echo "  ✗ deployment failed (HTTP $http):"; cat /tmp/vercel_deploy.json; echo; exit 1
fi

url=$(python3 -c 'import json; print(json.load(open("/tmp/vercel_deploy.json"))["url"])')
echo "  ✓ deployment created: https://${url}"
echo "→ Production alias: https://${PROJECT}.vercel.app"
