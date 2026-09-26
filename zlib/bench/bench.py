"""Zlib benchmark in Python with gzip (see README.md)."""
import gzip
import time
from pathlib import Path

GZ = Path("out/payload.gz").read_bytes()


def chk(b: bytes) -> int:
    h = 0
    for x in b:
        h = (h * 31 + x) & 0xFFFFFFFF
    return h


t0 = time.perf_counter()
out = gzip.decompress(GZ)
ms = (time.perf_counter() - t0) * 1000
print(f"inflate\t{ms:.3f}\t{chk(out)}")
