#!/bin/bash
# Bring in the latest citrolabs/ego-lite and re-apply the ego tiny layer.
#
#   tiny/sync-upstream.sh            merge upstream/main, re-apply the overlay, test
#   tiny/sync-upstream.sh --install  also rebuild and install the app
#
# Everything ego tiny adds lives in tiny/. Its changes to upstream files (the
# product rename, the AGENTS.md block) are deterministic transforms: on a
# conflict the upstream side wins and tiny/apply-overlay.sh applies them again.
# The top-level README.md is ego tiny's own and is kept as it is.
# See tiny/MAINTAINING.md.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -z "$(git status --porcelain)" ] || { echo "working tree is not clean; commit or stash first" >&2; exit 1; }
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/citrolabs/ego-lite.git
git fetch upstream main

before="$(git rev-parse HEAD)"
if git merge-base --is-ancestor upstream/main HEAD; then
	echo "already up to date with upstream/main"
else
	git merge --no-commit --no-ff -X theirs upstream/main || {
		# Files deleted on one side: keep upstream's decision.
		git status --porcelain | awk '/^(DU|UD|AU|UA|DD) /{print $2}' | while read -r f; do
			git checkout --theirs -- "$f" 2>/dev/null && git add -- "$f" || git rm -q -- "$f"
		done
	}
	# README.md belongs to ego tiny: keep ours whatever upstream did to theirs.
	git checkout HEAD -- README.md
	bash tiny/apply-overlay.sh
	git add -A
	git commit -q -m "Merge upstream ego-lite $(git rev-parse --short upstream/main) and re-apply the ego tiny overlay"
	echo "merged: $(git log --oneline "$before"..upstream/main | wc -l | tr -d ' ') upstream commits"
fi

(cd package/ego-browser && npm ci --ignore-scripts >/dev/null && npm test) ||
	echo "WARNING: runtime tests failed; review before installing" >&2

if [ "${1:-}" = "--install" ]; then
	bash tiny/build-tiny.sh --install
fi
