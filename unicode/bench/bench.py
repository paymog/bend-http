import time
import unicodedata
from pathlib import Path

TEXT = (Path(__file__).resolve().parent / "out" / "input.txt").read_bytes().decode("utf-8")


def utf8_cs(s: str) -> int:
    b = s.encode("utf-8")
    h = 0
    for x in b:
        h = (h * 31 + x) & 0xFFFFFFFF
    return (h + len(b)) & 0xFFFFFFFF


t0 = time.perf_counter()
out = unicodedata.normalize("NFC", TEXT)
ms = (time.perf_counter() - t0) * 1000
print(f"nfc\t{ms:.3f}\t{utf8_cs(out)}")
