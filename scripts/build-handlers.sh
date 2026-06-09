#!/usr/bin/env bash
set -euo pipefail

DIST="dist"
PKG="terraform/lambda-packages"
LAYER_DIR="$DIST/layer"
SHARED_OUT="$DIST/shared"

echo "=== Building shared Lambda Layer ==="

rm -rf "$SHARED_OUT" "$LAYER_DIR"

npx tsc \
  handlers/shared/index.ts \
  --outDir "$SHARED_OUT" \
  --declaration \
  --esModuleInterop \
  --moduleResolution node \
  --target ES2022 \
  --module commonjs \
  --skipLibCheck \
  --strict 2>&1

mkdir -p "$LAYER_DIR/nodejs/node_modules/digest-shared"
cp -r "$SHARED_OUT"/* "$LAYER_DIR/nodejs/node_modules/digest-shared/"

cd "$LAYER_DIR/nodejs"
npm init -y --quiet 2>&1 > /dev/null
npm install zod@^3.23.0 --no-audit --no-fund --omit=dev 2>&1 | tail -3
rm -f package.json package-lock.json
cd - > /dev/null

mkdir -p "$PKG" && cd "$LAYER_DIR" && zip -r "../../$PKG/digest-shared-layer.zip" . && cd ../..

echo "=== Building Lambda handlers ==="
mkdir -p "$DIST"

for LAMBDA in \
  subscribe-handler list-subscribers unsubscribe-handler \
  fetch-articles generate-newsletter send-emails \
  mark-newsletter-status notify-failure; do
  echo "  → $LAMBDA"
  mkdir -p "$DIST/$LAMBDA"

  npx esbuild "handlers/$LAMBDA/index.ts" \
    --bundle \
    --platform=node \
    --target=node24 \
    --external:@aws-sdk/* \
    --external:digest-shared \
    --outfile="$DIST/$LAMBDA/index.js" 2>&1

  if [ "$LAMBDA" = "unsubscribe-handler" ]; then
    cp "handlers/$LAMBDA/unsubscribed.html" "$DIST/$LAMBDA/"
  fi
  if [ "$LAMBDA" = "generate-newsletter" ]; then
    cp "handlers/$LAMBDA/template.hbs" "$DIST/$LAMBDA/"
  fi

  cd "$DIST/$LAMBDA" && zip -r "../../$PKG/$LAMBDA.zip" . && cd ../..
done

echo "=== Done ==="
