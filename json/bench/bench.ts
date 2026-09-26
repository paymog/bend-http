// Run with node or bun, from this folder, after run.py has written out/doc.json.
import { readFileSync } from "node:fs";

const TEXT = readFileSync("out/doc.json", "latin1");

function chk(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(h, 31) + s.charCodeAt(i)) >>> 0;
  return (h + s.length) >>> 0;
}

let t0 = performance.now();
const v = JSON.parse(TEXT);
let ms = performance.now() - t0;
console.log(`parse\t${ms.toFixed(3)}\t${chk(JSON.stringify(v))}`);

t0 = performance.now();
const out = JSON.stringify(v);
ms = performance.now() - t0;
console.log(`encode\t${ms.toFixed(3)}\t${chk(out)}`);
