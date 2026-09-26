// Run with node or bun after gen_input.py wrote out/input.txt.
import { readFileSync } from "node:fs";

const TEXT = readFileSync("out/input.txt", "utf8");

function utf8Cs(s: string): number {
  const b = new TextEncoder().encode(s);
  let h = 0;
  for (let i = 0; i < b.length; i++) h = (Math.imul(h, 31) + b[i]) >>> 0;
  return (h + b.length) >>> 0;
}

function graphemeCount(s: string): number {
  const seg = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  let n = 0;
  for (const _ of seg.segment(s)) n++;
  return n;
}

let t0 = performance.now();
const nfc = TEXT.normalize("NFC");
let ms = performance.now() - t0;
console.log(`nfc\t${ms.toFixed(3)}\t${utf8Cs(nfc)}`);

t0 = performance.now();
const n = graphemeCount(TEXT);
ms = performance.now() - t0;
console.log(`graphemes\t${ms.toFixed(3)}\t${n}`);
