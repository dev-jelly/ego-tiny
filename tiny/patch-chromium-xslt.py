#!/usr/bin/env python3
"""Backport the Chromium M156 libxslt fix into a verified ego ARM64 build.

Upstream: chromium/src commit 2ad9b7f5a86846e0b264090723a6a78964bb84c4.
This changes CVE-2026-125350's code path and leaves the engine version intact.
"""

import hashlib
import mmap
from pathlib import Path
import struct
import sys


# The full xsltTestCompMatchDirect routine, including the epilogue and cache
# update. File offsets and instruction encodings are specific to these builds.
ROUTINE_SIZE = 0x25C
ROUTINES = (
    (0xBA94498, "ba01ea1c9f5b0103fe38b05e6e8bdfe8a4854a943129a1d6aaa65611e208e951"),
    (0xBAA1558, "f3410d14d53baccc7aa9df67d1f804245b049a5ed29247e8db6be0d936231cc1"),
)


def patch(path: Path) -> None:
    with path.open("r+b") as binary, mmap.mmap(binary.fileno(), 0) as data:
        if data[:8] != bytes.fromhex("cffaedfe0c000001"):
            raise SystemExit("Expected a thin ARM64 Mach-O ego Framework")
        for offset, expected in ROUTINES:
            original = data[offset : offset + ROUTINE_SIZE]
            if hashlib.sha256(original).hexdigest() == expected:
                break
        else:
            raise SystemExit("Unsupported ego Framework for the Chromium XSLT backport")

        fixed = bytearray(original)
        # Restore the saved XPath context using a single load of ctxt->xpathCtxt.
        # Branch over the space reclaimed from the repeated loads.
        struct.pack_into(
            "<12I",
            fixed,
            0xD0,
            0xF94052A8,  # ldr x8, [x21, #0xa0]
            0xF900051B,  # str x27, [x8, #8]
            0xF900011C,  # str x28, [x8]
            0xF900291A,  # str x26, [x8, #0x50]
            0xB9005919,  # str w25, [x8, #0x58]
            0x290D4D14,  # stp w20, w19, [x8, #0x68]
            0x14000006,  # b +0x18 (validate the evaluated XPath object)
            # Reload ctxt->extras[sel->lenExtra].val before the original
            # null check and free. xmlXPathEval may have replaced this entry.
            0xF94082A9,  # ldr x9, [x21, #0x100]
            0xB9803308,  # ldrsw x8, [x24, #0x30]
            0x8B080508,  # add x8, x8, x8, lsl #1
            0xF8687936,  # ldr x22, [x9, x8, lsl #3]
            0x1400003C,  # b +0xf0 (original cached object null check)
        )
        # Route the cacheable path through the reload trampoline.
        struct.pack_into("<I", fixed, 0x12C, 0x3607FE08)  # tbz w8, #0, -0x40
        data[offset : offset + ROUTINE_SIZE] = fixed
    print("Applied Chromium CVE-2026-125350 XSLT backport")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} <path to ego Framework>")
    patch(Path(sys.argv[1]))
