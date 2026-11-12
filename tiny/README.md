# ego tiny

ego tiny is a telemetry-free build of the ego browser that installs next to
ego lite. This repository is a fork of
[citrolabs/ego-lite](https://github.com/citrolabs/ego-lite); everything ego
tiny adds lives in this `tiny/` directory.

## What it is made of

| Part | Source | How ego tiny changes it |
| --- | --- | --- |
| Browser app | the installed `/Applications/ego lite.app` (closed source) | copied, binary-patched, re-signed ad hoc as `/Applications/ego tiny.app` |
| `ego-browser` runtime | this repository (`package/ego-browser`) | built from source and loaded with `--sdk-path` |
| Agent skill | `tiny/skill` | installed as the separate `ego-tiny` skill |

`patch_app.py` points every vendor and analytics endpoint at `0.0.0.0`
(metrics, PostHog, Sentry, sync, remote feature flags, remote app-bundle
updates, the hosted chat panel, Langfuse) and renames the product. The updater
is deleted. `launcher.sh` adds DNS-level blocks for the same hosts and turns off
Chromium's built-in DNS client so VPN split DNS behaves as it does in Safari.
If a new ego lite release moves an endpoint, `patch_app.py` fails instead of
producing a build that still phones home.

## Living next to ego lite

| | ego lite | ego tiny |
| --- | --- | --- |
| App | `/Applications/ego lite.app` | `/Applications/ego tiny.app` |
| Bundle id | `com.citrolabs.ego.lite` | `com.citrolabs.ego.tiny` |
| Profile | `~/Library/Application Support/Citro Labs/ego lite` | `…/Citro Labs/ego tiny` |
| CLI | `ego-browser` | `ego-tiny` |
| Skill | `ego-browser` | `ego-tiny` |
| Runtime state | `~/.ego-browser/state` | `~/.ego-tiny/state` |

## Commands

```bash
tiny/build-tiny.sh --install     # rebuild from the installed ego lite and install
tiny/sync-upstream.sh --install  # merge upstream ego-lite, re-apply the rename, test, rebuild
```

Two things update independently:

- **Upstream repository** (runtime, guide, site learnings): `sync-upstream.sh`
  merges `upstream/main`. The only edit ego tiny makes to upstream files is the
  product rename, so conflicts are resolved in upstream's favour and
  `rename-source.sh` is applied again.
- **Browser app**: let ego lite update itself, then run
  `build-tiny.sh --install`. ego tiny never updates in place.
- Builds based on ego lite 0.6.2.9 or 0.6.2.10 apply the
  [Chromium M156 libxslt fix](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.96)
  for CVE-2026-125350 to the verified ARM64 routine before signing. The
  backport keeps the base Chromium version and covers that CVE only.

## Known limits

- Ad hoc signing: passkeys and Widevine DRM may not work, and macOS asks again
  for Local Network and other permissions.
- The side-panel AI chat is hosted by the vendor and is therefore dead.
- Standard Chromium connections to Google are reduced, not removed.
