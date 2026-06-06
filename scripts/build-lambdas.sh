#!/usr/bin/env bash
set -euo pipefail

DIST="dist"
PKG="terraform/lambda-packages"
LAYER_DIR="$DIST/layer"
SHARED_OUT="$DIST/shared"

echo "=== Building shared Lambda Layer ==="

rm -rf "$SHARED_OUT" "$LAYER_DIR"

# Compile shared TypeScript to CommonJS
npx tsc \
  handlers/shared/index.ts \
  --outDir "$SHARED_OUT" \
  --declaration \
  --moduleResolution node \
  --target ES2022 \
  --module commonjs \
  --skipLibCheck \
  --strict 2>&1

# Build layer structure
mkdir -p "$LAYER_DIR/nodejs/node_modules/digest-shared"
cp -r "$SHARED_OUT"/* "$LAYER_DIR/nodejs/node_modules/digest-shared/"

# Install layer dependencies (zod, ulid) at the layer nodejs root
cd "$LAYER_DIR/nodejs"
npm init -y --quiet 2>&1 > /dev/null
npm install zod@^3.23.0 ulid@^2.3.0 --no-audit --no-fund --omit=dev 2>&1 | tail -3
rm -f package.json package-lock.json
cd - > /dev/null

# Zip the layer
cd "$LAYER_DIR" && zip -r "../../$PKG/digest-shared-layer.zip" . && cd ../..

echo "=== Building Lambda handlers ==="
mkdir -p "$DIST"

for LAMBDA in subscribe-handler list-subscribers unsubscribe-handler; do
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

  cd "$DIST/$LAMBDA" && zip -r "../../$PKG/$LAMBDA.zip" . && cd ../..
done

echo "=== Done ==="
