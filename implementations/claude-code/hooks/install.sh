#!/usr/bin/env bash
# This script has been consolidated into the root install.sh.
# Delegating to avoid breaking existing workflows.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec "$REPO_DIR/install.sh" "$@"
