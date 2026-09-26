#!/usr/bin/env python3
"""Write the gzip input, build and run the zlib benchmark; print a markdown table. See README.md."""
import gzip, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
PLAIN = int(sys.argv[2]) if len(sys.argv) > 2 else 8_388_608
OP = "inflate"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}

VARIANTS = {
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def plain_bytes(n: int) -> bytes:
    return bytes((i * 31 + 7) & 255 for i in range(n))


def mbps(n: int, ms: float) -> float:
    return (n / 1_000_000) / (ms / 1000.0)


def main():
    OUT.mkdir(exist_ok=True)
    plain = plain_bytes(PLAIN)
    gz = gzip.compress(plain, compresslevel=6, mtime=0)
    (OUT / "payload.gz").write_bytes(gz)
    print(
        f"plain {PLAIN:,} bytes, gzip {len(gz):,} bytes",
        file=sys.stderr,
    )

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            err = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            sys.exit(f"build failed: {name}\n{err.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            lines = [l for l in r.stdout.splitlines() if len(l.split("\t")) == 3]
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in lines)})
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    seen = {checks[n].get(OP) for n in checks}
    if len(seen) != 1:
        sys.exit(f"checksum mismatch in {OP}: {[(n, checks[n].get(OP)) for n in checks]}")
    print(f"{OP} checksum {seen.pop()}", file=sys.stderr)

    names = list(table)
    best_ms = min(table[n][OP] for n in names) or 0.001
    best_mbps = max(mbps(PLAIN, table[n][OP]) for n in names)
    print("| variant | inflate ms | inflate MB/s | vs fastest |")
    print("|---:|---:|---:|---:|")
    for n in names:
        ms = table[n][OP]
        rate = mbps(PLAIN, ms)
        print(
            f"| {n} | {ms:,.1f} | {rate:,.0f} | "
            f"{ms / best_ms:.1f}x ms, {rate / best_mbps:.2f}x MB/s |"
        )


if __name__ == "__main__":
    main()
