// HTTP codec benchmark in JavaScript with the runtime's own HTTP parser (see README.md).
import { createRequire } from "node:module";

// Node's http server parser (llhttp). The module is legacy and not documented, but Node and Bun both ship it.
const { HTTPParser, methods } = createRequire(import.meta.url)("_http_common");

const N = 20000;
const REQ = Buffer.from(
  "POST /api/v1/items?page=2&sort=name HTTP/1.1\r\nHost: example.com\r\n" +
    "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\n" +
    "Accept: application/json, text/plain, */*\r\nAccept-Language: en-US,en;q=0.9\r\nAccept-Encoding: gzip, deflate, br\r\n" +
    "Content-Type: application/json\r\nCookie: session=0123456789abcdef; theme=dark\r\nConnection: keep-alive\r\n" +
    'Content-Length: 26\r\n\r\n{"name":"widget","qty":12}',
);
const RES = Buffer.from(
  "HTTP/1.1 200 OK\r\nDate: Fri, 25 Sep 2026 12:00:00 GMT\r\nServer: bend-kit\r\n" +
    "Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\n" +
    "X-Request-Id: 7f3c2a10-5b6e-4d8f-9a1b-2c3d4e5f6a7b\r\n" +
    'Content-Length: 34\r\n\r\n{"id":42,"name":"widget","qty":12}',
);

function fields(h: string[]): number {
  let s = 0;
  for (let i = 0; i < h.length; i += 2) s += h[i].length + h[i + 1].length + 1;
  return s;
}

function parse(kind: number, msg: Buffer): number {
  let s = 0;
  const p = new HTTPParser();
  p.initialize(kind, {});
  p[HTTPParser.kOnHeadersComplete] = (_maj: number, _min: number, h: string[], m: number, url: string, status: number) => {
    s += fields(h) + (kind === HTTPParser.REQUEST ? methods[m].length + url.length : status);
  };
  p[HTTPParser.kOnBody] = (b: Buffer) => {
    s += b.length;
  };
  const t0 = performance.now();
  for (let i = 0; i < N; i++) p.execute(msg);
  const ms = performance.now() - t0;
  console.log(`${kind === HTTPParser.REQUEST ? "parse_req" : "parse_res"}\t${ms.toFixed(1)}\t${s >>> 0}`);
  return s;
}

parse(HTTPParser.REQUEST, REQ);
parse(HTTPParser.RESPONSE, RES);
