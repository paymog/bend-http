"""HTTP codec benchmark in Python with h11 (see README.md)."""
import time

import h11

N = 20000
REQ = (
    b"POST /api/v1/items?page=2&sort=name HTTP/1.1\r\nHost: example.com\r\n"
    b"User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\n"
    b"Accept: application/json, text/plain, */*\r\nAccept-Language: en-US,en;q=0.9\r\nAccept-Encoding: gzip, deflate, br\r\n"
    b"Content-Type: application/json\r\nCookie: session=0123456789abcdef; theme=dark\r\nConnection: keep-alive\r\n"
    b'Content-Length: 26\r\n\r\n{"name":"widget","qty":12}'
)
RES = (
    b"HTTP/1.1 200 OK\r\nDate: Fri, 25 Sep 2026 12:00:00 GMT\r\nServer: bend-kit\r\n"
    b"Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\n"
    b"X-Request-Id: 7f3c2a10-5b6e-4d8f-9a1b-2c3d4e5f6a7b\r\n"
    b'Content-Length: 34\r\n\r\n{"id":42,"name":"widget","qty":12}'
)
REQ_BODY = b'{"name":"widget","qty":12}'
RES_BODY = b'{"id":42,"name":"widget","qty":12}'
# In the order Bend's encoders write them: sorted, with the framing headers Bend adds.
REQ_HEADERS = [
    ("accept", "application/json"), ("connection", "close"), ("content-length", "26"),
    ("content-type", "application/json"), ("host", "example.com"), ("user-agent", "bend-kit-bench/1.0"),
]
RES_HEADERS = [
    ("cache-control", "no-store"), ("content-length", "34"), ("content-type", "application/json; charset=utf-8"),
    ("date", "Fri, 25 Sep 2026 12:00:00 GMT"), ("server", "bend-kit"),
]


def fields(headers):
    return sum(len(k) + len(v) + 1 for k, v in headers)


def events(conn, data):
    conn.receive_data(data)
    head, body = None, 0
    while True:
        e = conn.next_event()
        if isinstance(e, h11.EndOfMessage):
            return head, body
        if isinstance(e, h11.Data):
            body += len(e.data)
        else:
            head = e


def parse_req():
    s = 0
    for _ in range(N):
        r, body = events(h11.Connection(h11.SERVER), REQ)
        s += len(r.method) + len(r.target) + fields(r.headers) + body
    return s


# h11 reads a response only on a connection that sent a request, and writes one only after it read one.
def clients():
    out = []
    for _ in range(N):
        c = h11.Connection(h11.CLIENT)
        c.send(h11.Request(method="GET", target="/", headers=[("host", "example.com")]))
        c.send(h11.EndOfMessage())
        out.append(c)
    return out


def servers():
    out = []
    for _ in range(N):
        c = h11.Connection(h11.SERVER)
        events(c, b"GET / HTTP/1.1\r\nhost: example.com\r\n\r\n")
        out.append(c)
    return out


def parse_res(conns):
    s = 0
    for c in conns:
        r, body = events(c, RES)
        s += r.status_code + fields(r.headers) + body
    return s


def encode_req():
    c = h11.Connection(h11.CLIENT)
    return (c.send(h11.Request(method="POST", target="/api/v1/items?page=2&sort=name", headers=REQ_HEADERS))
            + c.send(h11.Data(data=REQ_BODY)) + c.send(h11.EndOfMessage()))


def encode_res(c):
    return (c.send(h11.Response(status_code=200, reason="OK", headers=RES_HEADERS))
            + c.send(h11.Data(data=RES_BODY)) + c.send(h11.EndOfMessage()))


# Checksum: the sum over lines of h = h*31 + c (u32), so header order does not count.
def hash32(b):
    return sum(line_hash(line) for line in b.split(b"\n")) & 0xFFFFFFFF


def line_hash(line):
    h = 0
    for c in line:
        h = (h * 31 + c) & 0xFFFFFFFF
    return h


def run(name, f, *args):
    t0 = time.perf_counter()
    s = f(*args)
    ms = (time.perf_counter() - t0) * 1000
    return name, ms, s


def main():
    res_conns, req_conns = clients(), servers()
    rows = [run("parse_req", parse_req), run("parse_res", parse_res, res_conns)]
    name, ms, last = run("encode_req", lambda: [encode_req() for _ in range(N)])
    rows.append((name, ms, sum(map(len, last)) + hash32(last[-1])))
    name, ms, last = run("encode_res", lambda: [encode_res(c) for c in req_conns])
    rows.append((name, ms, sum(map(len, last)) + hash32(last[-1])))
    for name, ms, s in rows:
        print(f"{name}\t{ms:.1f}\t{s & 0xFFFFFFFF}")


main()
