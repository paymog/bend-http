# Zlib benchmark: gunzip one fixed member (see README.md).
import Base
import ../zlib.bend as Z

def from_bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, from_bytes(t)}

# Checksum: h = h*31 + c, u32, over every inflated byte.
def chk(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      chk(t, (h * 31 + c : U32))

def lap(+name: String, t0: Nat, t1: Nat, out: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(chk(out, 0)))

def op.inflated(t0: Nat, m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("inflate\t0\tfailed")
    case Some{+out}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        lap("inflate", t0, t1, out)

def op.inflate(s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.inflated(t0, Z.gunzip(s))

def bytes.of(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    op.inflate(from_bytes(bytes.of(r)))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 16777216)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    f : Result<&1, &1, U32 & String, File> <- File.open("out/payload.gz", "r")
    opened(f)
