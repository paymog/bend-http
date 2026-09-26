#!/usr/bin/env python3
"""Write out/input.txt: mixed scripts, TARGET UTF-8 bytes. See README.md."""
import sys
from pathlib import Path

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 else 1_000_000

# ASCII, Latin+marks, Hangul, Devanagari, emoji ZWJ, flags, CRLF.
SEED = (
    "The quick brown fox jumps over the lazy dog. 0123456789\n"
    "cafe\u0301 na\u0131ve co\u0308operate \u00e9\u00f1 "
    "\u1100\u1161\u11a8 \uAC00 \uD55C\uAE00 \uC548\uB155 "
    "\u0915\u093F\u092F\u093E \u0926\u0947\u0935\u0928\u093E\u0917\u0930\u0940 "
    "\U0001F468\u200D\U0001F469\u200D\U0001F467\u200D\U0001F466 "
    "\U0001F3FB\u200D\u2640\uFE0F "
    "\U0001F1FA\U0001F1F8 \U0001F1EC\U0001F1E7 "
    "\n"
)


def main() -> None:
    here = Path(__file__).resolve().parent
    out = here / "out"
    out.mkdir(exist_ok=True)
    seed = SEED.encode("utf-8")
    buf = bytearray()
    while len(buf) < TARGET:
        buf.extend(seed)
    path = out / "input.txt"
    path.write_bytes(buf)
    text = path.read_bytes().decode("utf-8")
    print(f"utf8_bytes={len(buf)} codepoints={len(text)}", file=sys.stderr)


if __name__ == "__main__":
    main()
