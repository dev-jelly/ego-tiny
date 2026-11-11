#!/bin/bash
# Bring in the latest citrolabs/ego-lite and re-apply the ego tiny layer.
#
#   tiny/sync-upstream.sh            merge upstream/main, rename, test
#   tiny/sync-upstream.sh --install  also rebuild and install the app
#
# Everything ego tiny adds lives in tiny/. The only change to upstream files is
# the product rename, which is a deterministic transform: on a conflict the
# upstream side wins and tiny/rename-source.sh is applied again.
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
	bash tiny/rename-source.sh
	git add -A
	git commit -q -m "Merge upstream ego-lite $(git rev-parse --short upstream/main) and re-apply ego tiny rename"
	echo "merged: $(git log --oneline "$before"..upstream/main | wc -l | tr -d ' ') upstream commits"
fi

(cd package/ego-browser && npm ci --ignore-scripts >/dev/null && npm test) ||
	echo "WARNING: runtime tests failed; review before installing" >&2

if [ "${1:-}" = "--install" ]; then
	bash tiny/build-tiny.sh --install
fi
