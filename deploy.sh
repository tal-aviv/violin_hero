#!/usr/bin/env bash
set -euo pipefail

# Load variables from .env if present
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

: "${VH_AUTH_ENDPOINT:?Set VH_AUTH_ENDPOINT in .env or environment}"
: "${VH_LOG_ENDPOINT:?Set VH_LOG_ENDPOINT in .env or environment}"
: "${VH_LOG_API_KEY:?Set VH_LOG_API_KEY in .env or environment}"

echo "▸ Building Flutter web…"
flutter build web --base-href "/violin_hero/" \
  --dart-define="VH_AUTH_ENDPOINT=$VH_AUTH_ENDPOINT" \
  --dart-define="VH_LOG_ENDPOINT=$VH_LOG_ENDPOINT" \
  --dart-define="VH_LOG_API_KEY=$VH_LOG_API_KEY"

echo "▸ Deploying to GitHub Pages…"
npx gh-pages -d build/web

echo "✓ Deployed to https://tal-aviv.github.io/violin_hero/"
