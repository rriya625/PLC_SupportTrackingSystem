#!/bin/bash
set -euo pipefail

ENVIRONMENT="${1:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/web"
DEPLOY_ROOT="${PLC_DEPLOY_ROOT_OVERRIDE:-$PROJECT_ROOT/deploy}"

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

for command_name in flutter git jq perl rsync; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required."
    exit 1
  fi
done

CONFIG_FILE="$PROJECT_ROOT/config.$ENVIRONMENT.json"
BASE_HREF="/$ENVIRONMENT/"
DEST_DIR="$DEPLOY_ROOT/$ENVIRONMENT"

BASE_URL_AUTH="$(jq -er '.AUTH_BASE_URL' "$CONFIG_FILE")"
BASE_URL_DATA="$(jq -er '.INTERFACE_BASE_URL' "$CONFIG_FILE")"
PACKAGE_VERSION="$(awk '/^version:/ {print $2; exit}' "$PROJECT_ROOT/pubspec.yaml")"
GIT_REVISION="$(git -C "$PROJECT_ROOT" rev-parse --short=12 HEAD)"
BUILD_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUILD_ID="${PACKAGE_VERSION}-${GIT_REVISION}-${BUILD_TIMESTAMP}"

echo "Building $ENVIRONMENT version $BUILD_ID"
rm -rf "$BUILD_DIR"

cd "$PROJECT_ROOT"
flutter build web --release \
  --base-href="$BASE_HREF" \
  --dart-define=BASE_URL_AUTH="$BASE_URL_AUTH" \
  --dart-define=BASE_URL_DATA="$BASE_URL_DATA" \
  --dart-define=BUILD_ENV="$ENVIRONMENT" \
  --dart-define=APP_BUILD_VERSION="$BUILD_ID"

cp "$CONFIG_FILE" "$BUILD_DIR/config.json"
TEMP_CONFIG="$(mktemp)"
jq \
  --arg version "$BUILD_ID" \
  --arg builtAt "$BUILD_TIMESTAMP" \
  '. + {BUILD_VERSION: $version, BUILD_TIMESTAMP_UTC: $builtAt}' \
  "$BUILD_DIR/config.json" > "$TEMP_CONFIG"
mv "$TEMP_CONFIG" "$BUILD_DIR/config.json"

perl -0pi -e "s/__APP_VERSION__/$BUILD_ID/g" "$BUILD_DIR/index.html"
jq -n \
  --arg version "$BUILD_ID" \
  --arg environment "$ENVIRONMENT" \
  --arg builtAt "$BUILD_TIMESTAMP" \
  '{version: $version, environment: $environment, builtAtUtc: $builtAt}' \
  > "$BUILD_DIR/version.json"

mkdir -p "$DEST_DIR"
rsync -av --delete "$BUILD_DIR/" "$DEST_DIR/"

echo "Build ready at $DEST_DIR"
