#!/usr/bin/env python3
"""Neutralise every outbound vendor/analytics endpoint in an ego lite app copy.

Usage: patch_app.py "<path>/ego tiny.app"

Binary patches are same-length byte replacements, so no offsets move.
Each endpoint must be found at least once; the script fails loudly if a new
ego lite release moved or renamed one, instead of silently leaving it live.
"""
import gzip
import pathlib
import re
import shutil
import struct
import subprocess
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


# Hosts inside the compressed web UI of resources.pak (chat panel, settings,
# onboarding). Entries are gzip or brotli, so a byte replace on the file cannot
# reach them: each affected entry is unpacked, rewritten and the pak rebuilt.
PAK_HOSTS = re.compile(
    rb"(?:[a-z0-9-]+\.)*citrolabs\.(?:ai|dev)"
    rb"|[a-z0-9]+\.ingest\.(?:us\.)?sentry\.io"
    rb"|(?:us|eu|app)(?:\.i)?\.posthog\.com"
    rb"|(?:us\.)?cloud\.langfuse\.com"
)
BROTLI_MAGIC = b"\x1e\x9b"


def ego_tiny_site() -> bytes:
    env = pathlib.Path(__file__).with_name("links.env").read_text()
    match = re.search(r"^EGO_TINY_SITE=(\S+)", env, re.M)
    if not match:
        raise SystemExit("EGO_TINY_SITE missing from tiny/links.env")
    return match.group(1).encode()


# Website links in the web UI (privacy, terms, docs, use cases) go to the
# ego tiny site instead of lite.ego.app; paths are kept.
PAK_SITE = re.compile(rb"https?://lite\.ego\.app")


def patch_pak(path: pathlib.Path) -> None:
    brotli = shutil.which("brotli")
    if not brotli:
        raise SystemExit("brotli CLI not found (brew install brotli); needed to patch resources.pak")
    data = path.read_bytes()
    version, _enc, count, aliases = struct.unpack_from("<IBxxxHH", data, 0)
    if version != 5:
        raise SystemExit(f"unexpected resources.pak version {version}")
    table = [struct.unpack_from("<HI", data, 12 + i * 6) for i in range(count + 1)]
    alias_bytes = data[12 + (count + 1) * 6 : 12 + (count + 1) * 6 + aliases * 4]
    blobs, patched, hits = [], 0, 0
    for i in range(count):
        blob = data[table[i][1] : table[i + 1][1]]
        if blob[:2] == b"\x1f\x8b":
            text, kind = gzip.decompress(blob), "gzip"
        elif blob[:2] == BROTLI_MAGIC:
            text = subprocess.run([brotli, "-d", "-c"], input=blob[8:], capture_output=True, check=True).stdout
            kind = "brotli"
        else:
            text, kind = blob, "raw"
        new, n = PAK_HOSTS.subn(b"0.0.0.0", text)
        new, links = PAK_SITE.subn(ego_tiny_site(), new)
        n += links
        if n:
            hits += n
            patched += 1
            if kind == "gzip":
                blob = gzip.compress(new, mtime=0)
            elif kind == "brotli":
                body = subprocess.run([brotli, "-c", "-q", "9"], input=new, capture_output=True, check=True).stdout
                blob = BROTLI_MAGIC + len(new).to_bytes(6, "little") + body
            else:
                blob = new
        blobs.append(blob)
    offset = 12 + (count + 1) * 6 + len(alias_bytes)
    out = bytearray(data[:12])
    for (rid, _), blob in zip(table, blobs):
        out += struct.pack("<HI", rid, offset)
        offset += len(blob)
    out += struct.pack("<HI", table[count][0], offset)
    out += alias_bytes
    for blob in blobs:
        out += blob
    path.write_bytes(bytes(out))
    print(f"resources.pak: {hits} vendor hosts neutralised in {patched} web UI entries")
    if not hits:
        raise SystemExit("no vendor hosts found in resources.pak (format changed; re-audit)")


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
    patch_pak(version_dir / "Resources/resources.pak")
    print("all known endpoints neutralised")
    rename_everywhere(app)


if __name__ == "__main__":
    main()
