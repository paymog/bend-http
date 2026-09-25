#!/usr/bin/env python3
"""Run GraphemeBreakTest.txt and NormalizationTest.txt against unicode.bend in a native build."""
import os
import subprocess
import sys

import gen

CHUNK = 200


def s(cps):
    return gen.s(cps)


def normalization():
    calls, part1, part = [], set(), None
    for n, line in enumerate(gen.ucd("NormalizationTest.txt"), 1):
        line = line.split("#")[0].strip()
        if line.startswith("@"):
            part = line
            continue
        if not line:
            continue
        cols = [[int(x, 16) for x in f.split()] for f in line.split(";")[:5]]
        if part == "@Part1":
            part1.add(cols[0][0])
        calls.append(f"n({n}, {', '.join(s(c) for c in cols)}, a)")
    # Part 1: every code point it does not list is its own NFC and NFD.
    runs, start = [], None
    for c in range(0x110001):
        if c < 0x110000 and c not in part1:
            start = c if start is None else start
        elif start is not None:
            runs.append(f"inv({c - start}n, {start}, a)")
            start = None
    return calls, runs


def graphemes():
    calls = []
    for n, line in enumerate(gen.ucd("GraphemeBreakTest.txt"), 1):
        line = line.split("#")[0].strip()
        if not line:
            continue
        clusters = [[int(x, 16) for x in part.replace("×", " ").split()]
                    for part in line.strip("÷ ").split("÷")]
        text = s([c for cl in clusters for c in cl])
        want = ", ".join(s(cl) for cl in clusters)
        calls.append(f"g({n}, {text}, [{want}], a)")
    return calls


HEAD = """import Base
import ./unicode.bend as U

def bad(-A: Data, +x: A, +ok: Bool, +acc: List<&2, A>) -> List<&2, A>:
  Bool.pick(List<&2, A>, ok, acc, x <> acc)

def n(+l: U32, +c1: String, +c2: String, +c3: String, +c4: String, +c5: String, acc: List<&2, U32>) -> List<&2, U32>:
  +c = String.eq(c2, U.nfc(c1)) && String.eq(c2, U.nfc(c2)) && String.eq(c2, U.nfc(c3)) && String.eq(c4, U.nfc(c4)) && String.eq(c4, U.nfc(c5))
  +d = String.eq(c3, U.nfd(c1)) && String.eq(c3, U.nfd(c2)) && String.eq(c3, U.nfd(c3)) && String.eq(c5, U.nfd(c4)) && String.eq(c5, U.nfd(c5))
  bad(U32, l, c && d, acc)

def inv(k: Nat, +c: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      +x = {SCon{Chr{c}, SNil{}} : String}
      inv(p, (c + 1 : U32), bad(U32, c, String.eq(x, U.nfc(x)) && String.eq(x, U.nfd(x)), acc))

def same(xs: List<&2, String>, ys: List<&2, String>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      String.eq(x, y) && same(xt, yt)
    case _ _:
      False{}

def g(+l: U32, s: String, want: List<&2, String>, acc: List<&2, U32>) -> List<&2, U32>:
  bad(U32, l, same(U.graphemes(s), want), acc)

def show(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, t}:
      " " ++ U32.show(x) ++ show(t)
"""


def chunks(prefix, calls):
    defs = []
    for i in range(0, len(calls), CHUNK):
        body = "".join(f"  a = {c}\n" for c in calls[i:i + CHUNK])
        defs.append(f"def {prefix}{i // CHUNK}(a: List<&2, U32>) -> List<&2, U32>:\n{body}  a\n")
    return defs


def suite(name, defs):
    run = "Nil{}"
    for i in range(len(defs)):
        run = f"{name}.c{i}({run})"
    return f"def {name}() -> List<&2, U32>:\n  {run}\n"


def main():
    gen.fetch()
    calls, runs = normalization()
    src = [HEAD]
    for name, cs in (("norm", calls), ("ident", runs), ("gb", graphemes())):
        defs = chunks(name + ".c", cs)
        src += defs
        src.append(suite(name, defs))
    src.append("""def report(name: String, +xs: List<&2, U32>) -> IO(Unit):
  IO.print(name ++ ": " ++ Nat.show(List.length(&2, U32, xs)) ++ " failures" ++ show(List.take(&2, U32, List.reverse(&2, U32, xs), 20n)))

def main() -> IO(Unit):
  do IO<Unit>:
    report("NormalizationTest", norm())
    report("NormalizationTest Part 1 identity", ident())
    report("GraphemeBreakTest", gb())
""")
    bend = os.path.join(gen.HERE, "ucdtest.bend")
    exe = os.path.join(gen.CACHE, "ucdtest")
    with open(bend, "w") as f:
        f.write("\n".join(src))
    try:
        subprocess.run(["bend", "ucdtest.bend", "-o", exe], cwd=gen.HERE, check=True)
    finally:
        os.remove(bend)
    out = subprocess.run([exe], check=True, capture_output=True, text=True).stdout
    print(out, end="")
    sys.exit(0 if all(" 0 failures" in l for l in out.splitlines()) else 1)


if __name__ == "__main__":
    main()
