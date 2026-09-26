// Run with node or bun. Buffer is the Node standard library's hex codec.
const REPS = 1 << 18;
const TEXT = "Hello \u00e9 \u03a9 \u20ac \u4e2d \u{1f600}\n".repeat(REPS);
const OCTETS = new TextEncoder().encode(TEXT);
const HEX = Buffer.from(OCTETS).toString("hex");

function chk(xs: Iterable<number>): number {
  let h = 0, n = 0;
  for (const x of xs) {
    h = (Math.imul(h, 31) + x) >>> 0;
    n++;
  }
  return (h + n) >>> 0;
}

function* codes(s: string): Iterable<number> {
  for (const c of s) yield c.codePointAt(0)!;
}

function lap<A, B>(name: string, f: (a: A) => B, x: A, toCodes: (b: B) => Iterable<number>) {
  const t0 = performance.now();
  const y = f(x);
  const ms = performance.now() - t0;
  console.log(`${name}\t${ms.toFixed(3)}\t${chk(toCodes(y))}`);
}

const enc = new TextEncoder();
const dec = new TextDecoder();
lap("utf8_encode", (s: string) => enc.encode(s), TEXT, (b) => b);
lap("utf8_decode", (b: Uint8Array) => dec.decode(b), OCTETS, codes);
lap("hex_encode", (b: Uint8Array) => Buffer.from(b.buffer, b.byteOffset, b.length).toString("hex"), OCTETS, codes);
lap("hex_decode", (s: string) => Buffer.from(s, "hex"), HEX, (b) => b);
