#!/usr/bin/env bash
# Refuses to release a tag that does not contain what develop shipped to main.
# 0.1.4 and 0.1.5 were tagged on main while the develop-to-main pull request was still open, so they shipped old code.
# Usage: scripts/check-release.sh vX.Y.Z, in a clone where origin/main and origin/develop are up to date.
set -euo pipefail

TAG="${1:?usage: scripts/check-release.sh vX.Y.Z}"
VERSION="${TAG#v}"
COMMIT="$(git rev-parse "$TAG^{commit}")"
MAIN="$(git rev-parse origin/main)"
FAILED=0

if [ "$COMMIT" != "$MAIN" ]; then
  echo "::error::$TAG points to ${COMMIT:0:7}, but main is at ${MAIN:0:7}. Tag the tip of main."
  FAILED=1
fi
if ! git merge-base --is-ancestor origin/develop "$COMMIT"; then
  echo "::error::develop has commits that are not in $TAG. Merge the develop-to-main pull request, then tag again."
  FAILED=1
fi
if ! git show "$COMMIT:CHANGELOG.md" | grep -q "^## \[${VERSION//./\\.}\]"; then
  echo "::error::CHANGELOG.md in $TAG has no '## [$VERSION]' section."
  FAILED=1
fi
[ "$FAILED" -eq 0 ] && echo "$TAG is the tip of main, contains develop and has a changelog section."
exit "$FAILED"
