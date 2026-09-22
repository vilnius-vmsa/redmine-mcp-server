#!/usr/bin/env bash
# Shared pip-audit invocation. Used by:
#   - .github/workflows/ci.validate.yml
#   - scripts/release.py (preflight)
#
# Keep the ignore list here, in one place, so local preflight and CI cannot drift.
#
# Invocation pattern from callers:
#   uv export --no-hashes --no-emit-project > /tmp/requirements-audit.txt
#   bash scripts/audit.sh -r /tmp/requirements-audit.txt --strict
#
# Ignored vulnerabilities (no upstream fix, or false-positive for our usage):
#   (none currently — add lines below as needed, with CVE id and justification)
set -e

# CI uses `uv tool run`, which installs a tool in an isolated ephemeral
# environment and deliberately does not add it to this shell's PATH. Prefer a
# locally installed audit tool for release preflight; otherwise let uv provide
# it for this one invocation.
if command -v pip-audit >/dev/null 2>&1; then
  exec pip-audit "$@"
fi

if command -v uv >/dev/null 2>&1; then
  exec uv tool run pip-audit "$@"
fi

echo "pip-audit or uv is required to run the dependency audit." >&2
exit 127
