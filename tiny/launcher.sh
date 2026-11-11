#!/bin/bash
# ego tiny launcher: start the patched browser with network-level blocks.
# The binary patches already point every known endpoint at 0.0.0.0; these
# resolver rules also stop anything the patches could not reach (web UI
# bundles inside resources.pak, future strings) from resolving at all.
#
# --disable-features=AsyncDns turns off Chromium's built-in DNS client (and
# with it DNS-over-HTTPS), so every lookup goes through macOS. That is what
# makes VPN split DNS (Tailscale MagicDNS, per-domain resolvers) behave the
# same as in Safari instead of depending on what Chromium read at startup.
HERE="$(cd "$(dirname "$0")" && pwd)"

BLOCK="MAP *.citrolabs.ai ~NOTFOUND"
BLOCK="$BLOCK, MAP citrolabs.ai ~NOTFOUND"
BLOCK="$BLOCK, MAP *.citrolabs.dev ~NOTFOUND"
BLOCK="$BLOCK, MAP *.ego.app ~NOTFOUND"
BLOCK="$BLOCK, MAP ego.app ~NOTFOUND"
BLOCK="$BLOCK, MAP *.posthog.com ~NOTFOUND"
BLOCK="$BLOCK, MAP *.sentry.io ~NOTFOUND"
BLOCK="$BLOCK, MAP *.langfuse.com ~NOTFOUND"

exec "$HERE/ego tiny" \
	--host-resolver-rules="$BLOCK" \
	--disable-posthog \
	--disable-breakpad \
	--disable-background-networking \
	--disable-component-update \
	--disable-domain-reliability \
	--no-pings \
	--disable-features=AsyncDns \
	--ego-server-name=ego-tiny \
	"$@"
