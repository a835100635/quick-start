#!/bin/bash
set -euo pipefail

# Consume the hook event payload so Cursor can close the pipe cleanly.
cat >/dev/null

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/build.sh" debug run
