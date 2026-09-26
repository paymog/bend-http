"""URL benchmark in Python with urllib.parse (see README.md)."""
import time
from urllib.parse import parse_qsl, quote, unquote, urlencode, urlsplit

ROUNDS = 10000
URLS = [
    "/",
    "/health",
    "/users",
    "/users/42",
    "/users/42/posts",
    "/users/42/posts/99",
    "/api/v1/items?page=2&sort=name",
    "/x?a=1&b=2",
    "/a%20b",
    "/a%20b?q=hello%20world",
    "/orgs/paymog/repos/bend-kit/issues/74",
    "/search?q=hello+world&limit=10",
    "/file/name%2Fwith%2Fslashes",
    "/?empty=",
    "/path?u=%2Fenc%2Foded",
    "nope",
]


def parse_query(qs: str) -> dict:
    if not qs:
        return {}
    out = {}
    for part in qs.split("&"):
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
        else:
            k, v = part, ""
        out[unquote(k)] = unquote(v)
    return out


def parse_origin(s: str):
    if not s.startswith("/"):
        return None
    p = urlsplit(s)
    path = unquote(p.path)
    return path, parse_query(p.query)


def encode_origin(path: str, q: dict) -> str:
    enc_path = quote(path, safe="/~")
    if not q:
        return enc_path
    pairs = sorted(q.items())
    return enc_path + "?" + urlencode(pairs, quote_via=quote)


def score(u):
    if u is None:
        return 0
    path, q = u
    s = len(path)
    for k, v in q.items():
        s += len(k) + len(v) + 1
    return s


def chk(s: str) -> int:
    h = 0
    for c in s:
        h = (h * 31 + ord(c)) & 0xFFFFFFFF
    return (h + len(s)) & 0xFFFFFFFF


def parse_round():
    acc = 0
    for _ in range(ROUNDS):
        for s in URLS:
            acc = (acc + score(parse_origin(s))) & 0xFFFFFFFF
    return acc


def parsed_samples():
    out = []
    for s in URLS:
        u = parse_origin(s)
        if u is not None:
            out.append(u)
    return out


def encode_round(samples):
    acc = 0
    for _ in range(ROUNDS):
        for path, q in samples:
            acc = (acc + chk(encode_origin(path, q))) & 0xFFFFFFFF
    return acc


t0 = time.perf_counter()
pchk = parse_round()
print(f"parse\t{(time.perf_counter() - t0) * 1000:.3f}\t{pchk}")

samples = parsed_samples()
t0 = time.perf_counter()
echk = encode_round(samples)
print(f"encode\t{(time.perf_counter() - t0) * 1000:.3f}\t{echk}")
