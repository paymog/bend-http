// Collections benchmark: JavaScript (see README.md). JavaScript has no sorted map,
// deque, or heap in its standard library, so only the vector (Array) runs.
const L = Number(process.argv[2] ?? 20);
const N = 1 << L;

const lcg = (x: number) => (Math.imul(x, 1664525) + 1013904223) >>> 0;

function lap(name: string, t0: number, chk: number) {
  console.log(`${name}\t${(performance.now() - t0).toFixed(3)}\t${chk >>> 0}`);
}

let t0 = performance.now();
const v: number[] = [];
for (let i = 0; i < N; i++) v.push(i);
lap("vec_push", t0, v.length);

t0 = performance.now();
let x = 1;
let acc = 0;
for (let i = 0; i < N; i++) {
  x = lcg(x);
  acc = (acc + v[x >>> (32 - L)]) >>> 0;
}
lap("vec_get", t0, acc);
