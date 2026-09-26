import time

REPS = 1 << 18
TEXT = "Hello \u00e9 \u03a9 \u20ac \u4e2d \U0001f600\n" * REPS
OCTETS = TEXT.encode()
HEX = OCTETS.hex()


def chk(xs) -> int:
    h, n = 0, 0
    for x in xs:
        h = (h * 31 + x) & 0xFFFFFFFF
        n += 1
    return (h + n) & 0xFFFFFFFF


def lap(name, f, x, codes):
    t0 = time.perf_counter()
    y = f(x)
    ms = (time.perf_counter() - t0) * 1000
    print(f"{name}\t{ms:.3f}\t{chk(codes(y))}")


lap("utf8_encode", str.encode, TEXT, iter)
lap("utf8_decode", lambda b: b.decode("utf-8", "replace"), OCTETS, lambda s: map(ord, s))
lap("hex_encode", bytes.hex, OCTETS, lambda s: map(ord, s))
lap("hex_decode", bytes.fromhex, HEX, iter)
