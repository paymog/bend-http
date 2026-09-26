// Run with node or bun, from this folder, after run.py has written out/payload.gz.
import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";

const gz = readFileSync("out/payload.gz");

function chk(b: Buffer): number {
  let h = 0;
  for (let i = 0; i < b.length; i++) h = (Math.imul(h, 31) + b[i]!) >>> 0;
  return h;
}

let t0 = performance.now();
const out = gunzipSync(gz);
const ms = performance.now() - t0;
console.log(`inflate\t${ms.toFixed(3)}\t${chk(out)}`);
