#!/bin/bash
set -e  # stop script on error

# ── CONFIG ──────────────────────────────────────────────────────
ENV=$1
VERSION=$(grep 'version:' pubspec.yaml | awk '{print $2}' | sed 's/+/-/')
BUILD_DIR="build/web"
DEPLOY_DIR="deploy"

# ── Dependency checks ──────────────────────────────────────────
for cmd in flutter jq rsync; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd not found. Please install it."
    exit 1
  fi
done

# ── Validate environment input ─────────────────────────────────
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
  echo "❌ Usage: ./build_web.sh [dev|prod]"
  exit 1
fi

# ── Set base href and destination folder ───────────────────────
if [ "$ENV" == "dev" ]; then
  BASE_HREF="/dev/"
  DEST_DIR="dev"
  BASE_URL_AUTH="https://support.porterlee.com/plc/intf/prospect/Auth0001/DEV/LoginAuth0001Service/"
  BASE_URL_DATA="https://support.porterlee.com/plc/intf/prospect/intf4010/DEV/BEASTProspectIntf4010APIService/"
  CONFIG_FILE="config.dev.json"
else
  BASE_HREF="/prod/"
  DEST_DIR="prod"
  BASE_URL_AUTH="https://support.porterlee.com/plc/intf/prospect/Auth0001/PROD/LoginAuth0001Service/"
  BASE_URL_DATA="https://support.porterlee.com/plc/intf/prospect/intf4010/PROD/BEASTProspectIntf4010APIService/"
  CONFIG_FILE="config.prod.json"
fi

echo "🚀 Building for environment: $ENV"
echo "🔧 Version: $VERSION"
echo "📁 Base href: $BASE_HREF"
echo "🌐 Auth URL: $BASE_URL_AUTH"
echo "🌐 Data URL: $BASE_URL_DATA"
echo "📂 Output directory: $DEPLOY_DIR/$DEST_DIR"

# ── Clean previous build ───────────────────────────────────────
echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"

# ── Build Flutter web (auto renderer) ──────────────────────────
echo "🏗️  Running Flutter build with AUTO renderer..."
flutter build web --release \
  --web-renderer auto \
  --base-href="$BASE_HREF" \
  --dart-define=BASE_URL_AUTH="$BASE_URL_AUTH" \
  --dart-define=BASE_URL_DATA="$BASE_URL_DATA" \
  --dart-define=BUILD_ENV="$ENV"

# ── Copy correct config.json ────────────────────────────────────
echo "📄 Preparing config.json..."
cp "$CONFIG_FILE" "$BUILD_DIR/config.json"

# ── Inject URLs into config.json ────────────────────────────────
echo "🔧 Injecting URLs into config.json..."
tmpfile=$(mktemp)
jq \
  --arg auth "$BASE_URL_AUTH" \
  --arg data "$BASE_URL_DATA" \
  '. + {AUTH_BASE_URL: $auth, INTERFACE_BASE_URL: $data}' \
  "$BUILD_DIR/config.json" > "$tmpfile" && mv "$tmpfile" "$BUILD_DIR/config.json"

# ── Copy to deploy target ───────────────────────────────────────
echo "📦 Copying build to deploy/$DEST_DIR..."
mkdir -p "$DEPLOY_DIR/$DEST_DIR"
rsync -av --exclude 'index.template.html' "$BUILD_DIR/" "$DEPLOY_DIR/$DEST_DIR/"

echo "✅ Build complete for $ENV (AUTO renderer). Deployed to: $DEPLOY_DIR/$DEST_DIR"
