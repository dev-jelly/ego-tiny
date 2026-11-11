#!/bin/bash
# Rename the product in this repository's sources: ego lite -> ego tiny.
# Idempotent, so it is re-run after every upstream merge. `ego-lite` with a
# hyphen (the upstream repository name and its URLs) is left alone on purpose.
set -euo pipefail
cd "$(dirname "$0")/.."
git grep -lIzE 'ego lite|Ego Lite|ego \(lite\)|Ego \(Lite\)|EGO LITE' -- . \
	':!tiny' ':!*package-lock.json' ':!.github' |
	xargs -0 perl -pi -e 's/ego lite/ego tiny/g; s/Ego Lite/Ego Tiny/g; s/ego \(lite\)/ego (tiny)/g; s/Ego \(Lite\)/Ego (Tiny)/g; s/EGO LITE/EGO TINY/g' || true
echo "renamed: $(git status --short -- . ':!tiny' | wc -l | tr -d ' ') files changed"
