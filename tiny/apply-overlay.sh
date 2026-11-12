#!/bin/bash
# Re-apply everything ego tiny changes in upstream files. Idempotent; run after
# every upstream merge (tiny/sync-upstream.sh does).
#
#   1. product rename
#   2. the ego tiny block at the top of AGENTS.md
#
# The top-level README.md is ego tiny's own file; sync-upstream.sh keeps it.
set -euo pipefail
cd "$(dirname "$0")/.."

bash tiny/rename-source.sh

if ! grep -q '<!-- ego-tiny:begin -->' AGENTS.md; then
	{ cat tiny/agents-head.md; cat AGENTS.md; } > AGENTS.md.new
	mv AGENTS.md.new AGENTS.md
	echo "AGENTS.md: ego tiny block added"
fi
