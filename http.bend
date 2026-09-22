import Base

# HTTP/1.1 over TCP. No TLS, no DNS, no chunked.
#   import ./http.bend as Http
#   Http.serve(~handler, 8080)
#   Http.get("127.0.0.1", 8080, "localhost", "/")

type Req is Data:
  Req{method: String, path: String, body: String}

type Res is Data:
  Res{status: U32, body: String}

def drop_cr.if(+s: String, cr: Bool) -> String:
  match cr:
    case True{}:
      String.reverse(String.drop(String.reverse(s), 1n))
    case False{}:
      s

def drop_cr(+s: String) -> String:
  drop_cr.if(s, String.ends_with(s, "\r"))

def first_line.list(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      drop_cr(h)

def first_line(s: String) -> String:
  first_line.list(String.lines(s))

def req_line.path(m: String, t: List<&2, String>) -> String & String:
  match t:
    case Nil{}:
      (m, "")
    case Con{p, u}:
      (m, p)

def req_line.list(xs: List<&2, String>) -> String & String:
  match xs:
    case Nil{}:
      ("", "")
    case Con{m, t}:
      req_line.path(m, t)

def req_line(s: String) -> String & String:
  req_line.list(String.split(s, ' '))

def split_at_blank.go(s: String, e: Bool, w: U32, acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+a}, t}:
      match e:
        case True{}:
          (String.reverse(acc), SCon{Chr{a}, t})
        case False{}:
          +w2 = (w * 256 + a : U32)
          split_at_blank.go(t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc})

def split_at_blank(s: String) -> String & String:
  split_at_blank.go(s, False{}, 0, SNil{})

def parse.words(mp: String & String, b: String) -> Req:
  (method, path) = mp
  Req{method, path, b}

def parse.line(line: String, b: String) -> Req:
  parse.words(req_line(line), b)

def parse.of(hb: String & String) -> Req:
  (head, b) = hb
  parse.line(first_line(head), b)

def parse(raw: String) -> Req:
  parse.of(split_at_blank(raw))

def body.of(hb: String & String) -> String:
  (h, b) = hb
  b

def body(s: String) -> String:
  body.of(split_at_blank(s))

def response(status: U32, body: String) -> String:
  "HTTP/1.1 " ++ U32.show(status) ++ " OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n" ++ body

def encode(r: Res) -> String:
  Res{status, body} = r
  response(status, body)

def get_req(host: String, path: String) -> String:
  "GET " ++ path ++ " HTTP/1.1\r\nHost: " ++ host ++ "\r\nConnection: close\r\n\r\n"

def get_tail(head: String, m: Socket & Result<&1, &1, U32 & String, String>) -> IO(String):
  (s, r) = m
  do IO<String>:
    tail : String <- IO.pass(String, r)
    Socket.close(s)
    return body(head ++ tail)

def get_head(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(String):
  (s, r) = m
  do IO<String>:
    head : String <- IO.pass(String, r)
    rest : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    get_tail(head, rest)

def get_sent(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(String):
  (s, r) = m
  do IO<String>:
    IO.pass(Unit, r)
    read : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    get_head(read)

def get(ip: String, port: U32, host: String, path: String) -> IO(String):
  do IO<String>:
    c    : Socket <- IO.try(Socket, TCP.connect(ip, port))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(c, get_req(host, path))
    get_sent(sent)

def sent_fin(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply_ok(~h: Req -> IO(Res), s: Socket, raw: String) -> IO(Unit):
  do IO<Unit>:
    res  : Res <- h(parse(raw))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, encode(res))
    sent_fin(sent)

def reply(~h: Req -> IO(Res), m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{raw}:
      reply_ok(~h, s, raw)
    case Fail{e}:
      Socket.close(s)

def talk(~h: Req -> IO(Res), s: Socket) -> IO(Unit):
  do IO<Unit>:
    read : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    reply(~h, read)

def conn(~h: Req -> IO(Res), m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~h, s))
    return l

@unsafe
def loop(~h: Req -> IO(Res), l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~h, m)
    loop(~h, l2)

def serve(~h: Req -> IO(Res), +port: U32) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(port))
    IO.print("http://127.0.0.1:" ++ U32.show(port))
    loop(~h, l)
