#!/bin/bash
# Re-apply everything ego tiny changes in upstream files. Idempotent; run after
# every upstream merge (tiny/sync-upstream.sh does).
#
#   1. product rename
#   2. project links and installer URLs (tiny/links.env)
#   3. the ego tiny block at the top of AGENTS.md
#
# The top-level README.md is ego tiny's own file; sync-upstream.sh keeps it.
set -euo pipefail
cd "$(dirname "$0")/.."

bash tiny/rename-source.sh
bash tiny/rebrand-links.sh

# Replace (or add) the ego tiny block so AGENTS.md always carries the current
# tiny/agents-head.md.
perl -0pi -e 's/\A<!-- ego-tiny:begin -->.*?<!-- ego-tiny:end -->\n*//s' AGENTS.md
{ cat tiny/agents-head.md; cat AGENTS.md; } > AGENTS.md.new
mv AGENTS.md.new AGENTS.md
