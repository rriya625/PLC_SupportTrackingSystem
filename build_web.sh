#!/bin/bash

# ── CONFIG ──────────────────────────────────────────────────────
ENV=$1
VERSION=$(grep 'version:' pubspec.yaml | awk '{print $2}' | sed 's/+/-/')
BUILD_DIR="build/web"
DEPLOY_DIR="deploy"

# Validate environment input
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
  echo "❌ Usage: ./build_web.sh [dev|prod]"
  exit 1
fi

# Set base href and destination folder
if [ "$ENV" == "dev" ]; then
  BASE_HREF="/dev/"
  DEST_DIR="dev"
  BASE_URL_AUTH="https://support.porterlee.com/plc/intf/prospect/Auth0001/DEV/LoginAuth0001Service/"
  BASE_URL_DATA="https://support.porterlee.com/plc/intf/prospect/intf4010/DEV/BEASTProspectIntf4010APIService/"
else
  BASE_HREF="/prod/"
  DEST_DIR="prod"
  BASE_URL_AUTH="https://support.porterlee.com/plc/intf/prospect/Auth0001/PROD/LoginAuth0001Service/"
  BASE_URL_DATA="https://support.porterlee.com/plc/intf/prospect/intf4010/PROD/BEASTProspectIntf4010APIService/"
fi

echo "🚀 Building for environment: $ENV"
echo "🔧 Version: $VERSION"
echo "📁 Base href: $BASE_HREF"
echo "🌐 Auth URL: $BASE_URL_AUTH"
echo "🌐 Data URL: $BASE_URL_DATA"
echo "📂 Output directory: $DEPLOY_DIR/$DEST_DIR"

# ── Build Flutter web ───────────────────────────────────────────
echo "🏗️  Running Flutter build..."
flutter build web --release \
  --base-href="$BASE_HREF" \
  --dart-define=BASE_URL_AUTH="$BASE_URL_AUTH" \
  --dart-define=BASE_URL_DATA="$BASE_URL_DATA"

# ── Copy to deploy target (excluding any template files) ────────
echo "📦 Copying build to deploy/$DEST_DIR..."
mkdir -p "$DEPLOY_DIR/$DEST_DIR"
rsync -av --exclude 'index.template.html' "$BUILD_DIR/" "$DEPLOY_DIR/$DEST_DIR/"

echo "✅ Build complete for $ENV. Deployed to: $DEPLOY_DIR/$DEST_DIR"