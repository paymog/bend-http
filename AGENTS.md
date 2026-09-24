# bend-net

HTTP/1.1 client packages written in Bend 2. Bend is new, so your priors about it are weak or wrong. Run `bend guide` before you write Bend code. It is the full language guide for the installed compiler. Where the two disagree, the checker is right. `bend base Map` prints one Base name and everything under it. `bend base --types` prints the Base types.

## Bend in brief

Bend looks like Python but acts like Haskell or Lean, with Rust-style resource rules.

- **Pure, with IO.** Effects live in `IO(T)` and run in `do IO<T>:` blocks. Every bind has a type: `x : T <- m`. `return v` wraps a pure value.
- **Affine by default.** A variable is used at most once. `+x` lets you use it more than once, but only when its type is `Data` (copyable). `-x` is erased: types and proofs only. `type T is Data:` is copyable; `type T is Type:` is not. Closures, arrays, and handles (`Socket`, `File`) are `Type`, so every effect on a handle gives the handle back beside its result.
- **Quantities in types.** `&0`, `&1`, `&2` say how often values of a type may be used. You see them everywhere here: `Maybe<&2, String>`, `Map<&2, List<&2, String>>`, `Result<&1, &1, U32 & String, Socket>`. `A & B` is a pair type; `(a, b)` is a pair value.
- **Little inference.** Every operator expression needs a type: `(n - 16 : U32)`, `(t1 - t0 : Nat)`. Inside `( : T)`, operators call `T.add` and so on. A bare `a - b` is rejected, even though `bend guide` still says it means `Nat`. `==` is only the equality type. For a value test, call `U32.is_eq(a, b)` or `String.eq(a, b)`.
- **No `if`.** Match on `True{}` / `False{}`, or use `Bool.pick(T, cond, a, b)`.
- **`match` takes only a parameter or a pattern-bound variable.** A computed value cannot be the scrutinee, and `(a, b) = f(x)` counts as a match. Pass the value to a helper that matches on its parameter. This is why the code has chains like `fields_put.key` → `fields_put.dup`, and `drop_cr` → `drop_cr.if`. Match parameters in the order they are declared: to match a `Bool` flag before destructuring an earlier parameter, put the flag first. Dots in names are only characters.
- **Define before use.** A def can call only defs above it in the file (or imported), so helpers go first.
- **Termination is checked.** Each recursive call must pass a structurally smaller piece of its input, and the checker reads arguments left to right, so put the shrinking parameter first. Mutual recursion is not allowed. Merge the functions into one def with a selector argument. For loops bounded by the outside world, count down a `Nat` fuel argument. `@unsafe` skips the check and loses the proof guarantees; avoid adding it (see ROADMAP.md).
- **Literals.** `42` is `U32`, `3n` is `Nat`, `'c'` is `Char`, `"s"` is `String`. A `String` is a list of `Char`: `SCon{Chr{c}, t}` / `SNil{}`. Lists are `Con{h, t}` / `Nil{}`, and `[a, b]` or `h <> t`.
- **Modules.** `import ./url/url.bend as Url` makes `Url.x` name each def in that file. A registry package imports by content hash: `import 0x<hash>/http.bend as Http`.

## Laws and proofs

A law is a claim; a proof is a def with the same name. Each package has:

- `LAWS.bend`: the claims, each `law name:` over an equality `{a == b : T}`. The human owns this file. Change a law only when the user asks.
- `PROOF.bend`: imports `LAWS.bend` and proves each law as `def Laws.name():`. Most laws here are concrete fixtures, so the proof is `{==}` (both sides compute to the same term).
- `bend PROOF.bend` is the gate. It prints "All terms check." when every law holds. An open or false law fails it.

## Repo facts

- Bodies and socket data are byte strings: one `Char` per octet (0..255). `Http.text` decodes UTF-8.
- Foreign effects are defs whose body is `import "./effs/wire.c"` plus `import "./effs/wire.js"`. Every effect needs both twins, and the host function name is the def name, lowercased, with dots as underscores. Read `bend guide effects` before you write one. Proofs do not cover host code.
- `bend file.bend` runs through the checker's runner and overflows on strings over about 30 KB. Build big-body programs natively: `bend file.bend -o app`.
- The registry shows the first comment line of the first file in path order as the package description. `about.bend` exists for that reason. Keep the first comment in each package's first file a one-line description.
- CI (`.github/workflows/ci.yml`) is the list of checks to run: `bend PROOF.bend` and `bend check.bend` in the root, `bend PROOF.bend` in each package folder, then each package's `check.bend`. `smoke.bend` does live fetches. Run `bend <file> --check-only` for a fast type check.
- Packages publish to the Elbow registry (`elbow add http@0.9.2`), not the Bend hub. A breaking change needs a new version.
