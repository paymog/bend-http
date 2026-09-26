// Router benchmark: match 16 requests against 8 routes with URLPattern, N rounds (see README.md).
const ROUNDS = 10000;

const ROUTES: [string, string, string[]][] = [
  ["GET", "/health", []],
  ["GET", "/users", []],
  ["POST", "/users", []],
  ["GET", "/users/:id", ["id"]],
  ["PUT", "/users/:id", ["id"]],
  ["GET", "/users/:id/posts", ["id"]],
  ["GET", "/users/:id/posts/:post", ["id", "post"]],
  ["GET", "/orgs/:org/repos/:repo/issues/:num", ["org", "repo", "num"]],
];

const REQUESTS: [string, string][] = [
  ["GET", "/health"],
  ["GET", "/users"],
  ["POST", "/users"],
  ["GET", "/users/42"],
  ["PUT", "/users/42"],
  ["DELETE", "/users/42"],
  ["GET", "/users/7/posts"],
  ["GET", "/users/7/posts/99"],
  ["GET", "/orgs/bendlang/repos/bend/issues/1077"],
  ["GET", "/orgs/bendlang/repos/bend"],
  ["GET", "/missing"],
  ["POST", "/health"],
  ["GET", "/users/alice"],
  ["GET", "/users/alice/posts/first"],
  ["PUT", "/users/bob/posts"],
  ["GET", "/orgs/paymog/repos/bend-kit/issues/73"],
];

const mix = (h: number, x: number) => (Math.imul(h, 31) + x) >>> 0;

const routes = ROUTES.map(([method, pat, names]) => [method, new URLPattern({ pathname: pat }), names] as const);

const t0 = performance.now();
let h = 0;
for (let n = 0; n < ROUNDS; n++) {
  for (const [method, path] of REQUESTS) {
    let i = 0;
    for (; i < routes.length; i++) {
      const [want, pat, names] = routes[i];
      if (want !== method) continue;
      const m = pat.exec({ pathname: path });
      if (!m) continue;
      h = mix(h, i + 1);
      for (const k of names) for (const c of m.pathname.groups[k]!) h = mix(h, c.charCodeAt(0));
      break;
    }
    if (i === routes.length) h = mix(h, 0);
  }
}
const ms = performance.now() - t0;
console.log(`route\t${ms.toFixed(1)}\t${h}`);
