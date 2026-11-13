#!/bin/bash
# Point the upstream sources' project links at ego tiny (values in tiny/links.env)
# instead of Citro Labs. Idempotent; tiny/apply-overlay.sh runs it after every
# upstream merge.
#
# Rewritten:  lite.ego.app -> EGO_TINY_SITE, cdn.ego.app installers ->
#             EGO_TINY_DOWNLOAD, citrolabs/ego-lite -> EGO_TINY_REPO,
#             citrolabs maintainer fields -> EGO_TINY_OWNER / EGO_TINY_CONTACT.
# Left alone: tiny/ and the top-level README.md (ego tiny's own files, which
#             name the original on purpose), .github/ (upstream CI), lock files.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
# shellcheck source=links.env
. tiny/links.env
set +a

git grep -lIzE 'citrolabs|ego\.app' -- . \
	':!tiny' ':!README.md' ':!.github' ':!*package-lock.json' |
	xargs -0 -r perl -pi -e '
		BEGIN {
			($site, $dl, $repo, $owner, $mail) =
				@ENV{qw(EGO_TINY_SITE EGO_TINY_DOWNLOAD EGO_TINY_REPO EGO_TINY_OWNER EGO_TINY_CONTACT)};
			($repo_name) = $repo =~ m{/(.+)$};
			($site_host) = $site =~ m{^https?://([^/]+)};
		}
		# The ego tiny block in AGENTS.md names the original on purpose.
		next if /<!-- ego-tiny:begin -->/ .. /<!-- ego-tiny:end -->/;
		# Installers: macOS DMGs -> the ego tiny DMG; Windows has no build.
		s{https://cdn\.ego\.app/setup/macos/[^\s"\x27)<>]+\.dmg}{$dl}g;
		s{https://cdn\.ego\.app/setup/windows/[^\s"\x27)<>]+}{$site/}g;
		# Website, docs, privacy, terms: same paths on the ego tiny site.
		s{https?://lite\.ego\.app}{$site}g;
		s{\blite\.ego\.app\b}{$site_host}g;   # link text, badges
		# Repository, issues, raw files, marketplace ids.
		s{citrolabs/ego-lite}{$repo}g;
		s{github\.com/citrolabs\b}{github.com/$owner}g;
		# Maintainer fields in manifests.
		s{contact\@citrolabs\.ai}{$mail}g;
		s{"\@citrolabs/ego"}{"\@$owner/$repo_name"}g;
		s{("(?:name|author|developerName)"\s*:\s*)"citrolabs"}{$1"$owner"}g;
		# Plugin ids, so the ego tiny plugin does not collide with ego lite\x27s.
		s{\@citrolabs(\\?)/ego\b}{\@$owner$1/$repo_name}g;
		s{"citrolabs\.ego"}{"$owner.$repo_name"}g;
		# Trendshift ranks the upstream repository; drop its badge.
		s{<a href="https://trendshift\.io/repositories/42334[^\n]*?</a>\s*}{}g;
	'

left="$(git grep -lIzE 'citrolabs/ego-lite|lite\.ego\.app|cdn\.ego\.app|contact@citrolabs' -- . \
	':!tiny' ':!README.md' ':!.github' ':!*package-lock.json' |
	xargs -0 -r perl -ne '
		next if /<!-- ego-tiny:begin -->/ .. /<!-- ego-tiny:end -->/;
		print "$ARGV:$.: $_" if m{citrolabs/ego-lite|lite\.ego\.app|cdn\.ego\.app|contact\@citrolabs};
		close ARGV if eof;
	' || true)"
if [ -n "$left" ]; then
	echo "rebrand-links: unhandled references remain:" >&2
	echo "$left" >&2
	exit 1
fi
echo "links: $(git status --short -- . ':!tiny' | wc -l | tr -d ' ') files differ from HEAD"
