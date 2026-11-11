#!/usr/bin/env python3
"""Neutralise every outbound vendor/analytics endpoint in an ego lite app copy.

Usage: patch_app.py "<path>/ego tiny.app"

Binary patches are same-length byte replacements, so no offsets move.
Each endpoint must be found at least once; the script fails loudly if a new
ego lite release moved or renamed one, instead of silently leaving it live.
"""
import pathlib
import sys

# Same-length replacement: keep the scheme, point the host at 0.0.0.0 (which
# Chromium refuses with ERR_ADDRESS_INVALID before any packet leaves), pad the
# path so the string length is unchanged.
BINARY_URLS = [
    b"https://us.i.posthog.com/batch/",  # PostHog product analytics
    b"https://eventflow.citrolabs.ai/metrics",  # UMA/UKM upload
    b"https://o4511212523159552.ingest.us.sentry.io/api/4512332203360256/envelope/?sentry_key=16b9375bc43b1229d40407550708f95c",
    b"https://o4511212523159552.ingest.us.sentry.io/api/4511212845727744/minidump/?sentry_key=f6c9392e85292d35cb5c09a03bc79351",
    b"https://test-sync.citrolabs.ai/ego-sync",
    b"https://sync.citrolabs.ai/ego-sync",
    b"https://variations.ego.app/seed",  # remote feature-flag seed
    b"http://variations.ego.app/seed",
    b"https://cdn.citrolabs.ai/app-bundle/",  # remotely updated app code
    b"https://app.citrolabs.ai/chatbot",  # hosted chat panel
    b"https://update.citrolabs.ai/service/update2",  # updater
]

# Text replacements for the bundled Node daemon (plain JS, length is free).
DAEMON_TEXT = [
    (b"o4511212523159552.ingest.us.sentry.io", b"0.0.0.0"),
    (b"us.cloud.langfuse.com", b"0.0.0.0"),
    # chat panel web client (voice upload, file host, analytics)
    (b"speech.citrolabs.ai", b"0.0.0.0"),
    (b"files.citrolabs.ai", b"0.0.0.0"),
    (b"api.citrolabs.ai", b"0.0.0.0"),
    (b"us.i.posthog.com", b"0.0.0.0"),
    (b"app.posthog.com", b"0.0.0.0"),
]


def dead_url(url: bytes) -> bytes:
    scheme, rest = url.split(b"://", 1)
    head = scheme + b"://0.0.0.0/"
    pad = len(url) - len(head)
    if pad < 0:
        raise SystemExit(f"URL too short to neutralise: {url!r}")
    tail = b"/" if url.endswith(b"/") and pad > 0 else b""
    out = head + b"x" * (pad - len(tail)) + tail
    assert len(out) == len(url)
    return out


def patch_file(path: pathlib.Path, pairs, required: set) -> None:
    data = path.read_bytes()
    changed = False
    for old, new in pairs:
        n = data.count(old)
        if n:
            data = data.replace(old, new)
            required.discard(old)
            changed = True
            print(f"  {n}x {old.decode()[:70]}  ({path.name})")
    if changed:
        path.write_bytes(data)


# Product names. Every pair is the same length, so the replacement is safe in
# Mach-O files and .pak resources as well as in text.
RENAMES = [
    (b"ego lite", b"ego tiny"),
    (b"ego (lite)", b"ego (tiny)"),
    (b"Ego Lite", b"Ego Tiny"),
    (b"Ego (Lite)", b"Ego (Tiny)"),
    (b"EGO LITE", b"EGO TINY"),
    # UTF-16LE copies (InfoPlist.strings, some resources)
    ("ego lite".encode("utf-16-le"), "ego tiny".encode("utf-16-le")),
    ("ego (lite)".encode("utf-16-le"), "ego (tiny)".encode("utf-16-le")),
]


def rename_everywhere(app: pathlib.Path) -> None:
    total = 0
    for path in sorted(app.rglob("*")):
        if path.is_symlink() or not path.is_file():
            continue
        data = path.read_bytes()
        hits = sum(data.count(old) for old, _ in RENAMES)
        if not hits:
            continue
        for old, new in RENAMES:
            data = data.replace(old, new)
        path.write_bytes(data)
        total += hits
    print(f"renamed {total} product-name strings")


def main() -> None:
    app = pathlib.Path(sys.argv[1])
    versions = app / "Contents/Frameworks/ego Framework.framework/Versions"
    version_dir = next(p for p in versions.iterdir() if p.is_dir() and not p.is_symlink())

    url_pairs = [(u, dead_url(u)) for u in BINARY_URLS]
    binaries = [
        app / "Contents/MacOS/ego tiny",
        version_dir / "ego Framework",
        version_dir / "Helpers/ego-browser",
    ]
    # The updater URL lives only in the updater (deleted) and Info.plist.
    required = {u for u in BINARY_URLS if b"update.citrolabs.ai" not in u}
    print("binary endpoints:")
    for binary in binaries:
        patch_file(binary, url_pairs, required)

    daemon = version_dir / "Resources/local-ego-daemon"
    required_daemon = {old for old, _ in DAEMON_TEXT}
    print("daemon endpoints:")
    for path in sorted(daemon.rglob("*")):
        if path.is_file() and path.suffix in {".mjs", ".js", ".html", ".json"}:
            patch_file(path, DAEMON_TEXT + url_pairs, required_daemon)

    missing = required | required_daemon
    if missing:
        raise SystemExit(
            "endpoints not found (ego lite changed; re-audit before trusting this build):\n  "
            + "\n  ".join(m.decode() for m in sorted(missing))
        )
    print("all known endpoints neutralised")
    rename_everywhere(app)


if __name__ == "__main__":
    main()
