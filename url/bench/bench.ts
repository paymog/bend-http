// URL benchmark in JavaScript with manual RFC 3986 query parsing (see README.md).
const ROUNDS = 10000;
const URLS = [
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
];

type Sample = { path: string; q: [string, string][] };

function dec(s: string): string {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
}

function parseQuery(qs: string): [string, string][] {
  if (!qs) return [];
  const out: [string, string][] = [];
  for (const part of qs.split("&")) {
    if (!part) continue;
    const eq = part.indexOf("=");
    if (eq < 0) out.push([dec(part), ""]);
    else out.push([dec(part.slice(0, eq)), dec(part.slice(eq + 1))]);
  }
  return out;
}

function parseOrigin(s: string): Sample | null {
  if (!s.startsWith("/")) return null;
  const qm = s.indexOf("?");
  const path = dec(qm < 0 ? s : s.slice(0, qm));
  const q = parseQuery(qm < 0 ? "" : s.slice(qm + 1));
  return { path, q: q.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0)) };
}

function encSeg(s: string): string {
  return encodeURIComponent(s).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

function encodePath(path: string): string {
  return path
    .split("/")
    .map((seg, i) => (i === 0 ? "" : encSeg(seg)))
    .join("/");
}

function encodeOrigin(path: string, q: [string, string][]): string {
  const out = encodePath(path) || "/";
  if (!q.length) return out;
  return `${out}?${q.map(([k, v]) => `${encSeg(k)}=${encSeg(v)}`).join("&")}`;
}

function score(u: Sample | null): number {
  if (!u) return 0;
  let s = u.path.length;
  for (const [k, v] of u.q) s += k.length + v.length + 1;
  return s;
}

function chk(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(h, 31) + s.charCodeAt(i)) >>> 0;
  return (h + s.length) >>> 0;
}

function parseRound(): number {
  let acc = 0;
  for (let r = 0; r < ROUNDS; r++) {
    for (const s of URLS) acc = (acc + score(parseOrigin(s))) >>> 0;
  }
  return acc;
}

function parsedSamples(): Sample[] {
  const out: Sample[] = [];
  for (const s of URLS) {
    const u = parseOrigin(s);
    if (u) out.push(u);
  }
  return out;
}

function encodeRound(samples: Sample[]): number {
  let acc = 0;
  for (let r = 0; r < ROUNDS; r++) {
    for (const { path, q } of samples) acc = (acc + chk(encodeOrigin(path, q))) >>> 0;
  }
  return acc;
}

let t0 = performance.now();
const pchk = parseRound();
console.log(`parse\t${(performance.now() - t0).toFixed(3)}\t${pchk}`);

const samples = parsedSamples();
t0 = performance.now();
const echk = encodeRound(samples);
console.log(`encode\t${(performance.now() - t0).toFixed(3)}\t${echk}`);
