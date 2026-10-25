#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/tool/build_web_release.sh" "$@"
