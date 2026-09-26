# Wire benchmark: one localhost TCP echo with send.words and recv.words (see README.md).
import Base
import ../wire.bend as Wire

def port() -> U32:
  38475

def len() -> U32:
  1048576

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def packw(+t: U32) -> U32:
  (b8(t) .|. (b8((t + 31 : U32)) << 8n) .|. (b8((t + 62 : U32)) << 16n) .|. (b8((t + 93 : U32)) << 24n) : U32)

def fill(n: Nat, a: Array<U32>, +j: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill(p, Array.set(U32, a, j, packw((j * 124 + 7 : U32))), (j + 1 : U32))

def buf() -> Array<U32>:
  fill(264704n, Array.new(U32, 18n, 0), 0)

def byte.of(+sh: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (b, w) = r
  (b, b8(U32.shrn(w, U32.to_nat(sh))))

def byte(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  byte.of(((i .&. 3 : U32) * 8 : U32), Array.get(U32, a, (i >> 2n : U32)))

def chk() -> U32:
  470

def lap(+name: String, t0: Nat, t1: Nat, +cs: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(cs))

def echo.sent(ms: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (_, r) = ms
  match r:
    case Fail{e}:
      IO.print("server send failed")
    case Done{u}:
      IO.sleep(0)

def echo.got(sock2: Socket, pair: U32 & Array<U32>) -> IO(Unit):
  (ln, words) = pair
  do IO<Unit>:
    ms : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(sock2, ln, words)
    echo.sent(ms)

def echo.done(mr: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  (sock2, r) = mr
  match r:
    case Fail{e}:
      IO.print("server recv failed")
    case Done{pair}:
      echo.got(sock2, pair)

def echo(sock: Socket) -> IO(Unit):
  do IO<Unit>:
    mr : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(sock, len(), 30000)
    echo.done(mr)

def server.accept(mr: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  (_, r) = mr
  match r:
    case Fail{e}:
      IO.print("accept failed")
    case Done{sock}:
      echo(sock)

def server.listen(l: Listener) -> IO(Unit):
  do IO<Unit>:
    mr : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    server.accept(mr)

def server.lr(lr: Result<&1, &1, U32 & String, Listener>) -> IO(Unit):
  match lr:
    case Fail{e}:
      IO.print("listen failed")
    case Done{l}:
      server.listen(l)

def server() -> IO(Unit):
  do IO<Unit>:
    lr : Result<&1, &1, U32 & String, Listener> <- TCP.listen(port())
    server.lr(lr)

def client.recv.lap(t0: Nat, t1: Nat, +cs: U32) -> IO(Unit):
  lap("recv", t0, t1, cs)

def client.recv.got(t0: Nat, pair: U32 & Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    client.recv.lap(t0, t1, chk())

def client.recv.done(t0: Nat, mr: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, +exp: U32) -> IO(Unit):
  (_, r) = mr
  match r:
    case Fail{e}:
      IO.print("recv failed")
    case Done{pair}:
      client.recv.got(t0, pair)

def client.recv.go(sock: Socket, +exp: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    mr : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(sock, len(), 30000)
    client.recv.done(t0, mr, exp)

def client.send.lap(t0: Nat, t1: Nat, +cs: U32) -> IO(Unit):
  lap("send", t0, t1, cs)

def client.send.done(t0: Nat, mr: Socket & Result<&1, &1, U32 & String, Unit>, +cs: U32) -> IO(Unit):
  (sock, r) = mr
  match r:
    case Fail{e}:
      IO.print("send failed")
    case Done{u}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        client.send.lap(t0, t1, cs)
        client.recv.go(sock, cs)

def client.send.go(t0: Nat, sock: Socket, words: Array<U32>, +cs: U32) -> IO(Unit):
  do IO<Unit>:
    mr : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(sock, len(), words)
    client.send.done(t0, mr, cs)

def client.prep(sock: Socket, words: Array<U32>, +cs: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    client.send.go(t0, sock, words, cs)

def client.ready(sock: Socket, words: Array<U32>) -> IO(Unit):
  client.prep(sock, words, chk())

def client.connected(sock: Socket) -> IO(Unit):
  client.ready(sock, buf())

def client.cr(cr: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match cr:
    case Fail{e}:
      IO.print("connect failed")
    case Done{sock}:
      client.connected(sock)

def client.go() -> IO(Unit):
  do IO<Unit>:
    cr : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", port(), 10000)
    client.cr(cr)

def main() -> IO(Unit):
  do IO<Unit>:
    chan : Chan(Unit) <- IO.fork(Unit, server())
    _ : Unit <- IO.sleep(200)
    u : Unit <- client.go()
    IO.join(Unit, chan)
