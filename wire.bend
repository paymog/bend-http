import Base

# Socket IO on octets: one Char per byte (0..255). Base's TCP/UDP effects
# decode UTF-8, which breaks byte counts and binary protocols.
#   import ./wire.bend as Wire

def recv(sock: Socket, max: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, String>):
  import "./effs/wire.c"
  import "./effs/wire.js"

def send(sock: Socket, data: String) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):
  import "./effs/wire.c"
  import "./effs/wire.js"

def recv_from(sock: Socket, max: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, String & U32 & String>):
  import "./effs/wire.c"
  import "./effs/wire.js"

def send_to(sock: Socket, host: String, port: U32, data: String) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):
  import "./effs/wire.c"
  import "./effs/wire.js"

# TLS over a connected TCP socket (OpenSSL 3, loaded at run time; BEND_LIBSSL
# overrides its path). The certificate chain and host name are always checked.
def tls.connect(sock: Socket, host: String) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):
  import "./effs/wire.c"
  import "./effs/wire.js"

def tls.send(sock: Socket, data: String) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):
  import "./effs/wire.c"
  import "./effs/wire.js"

# "" once the peer has closed.
def tls.recv(sock: Socket, max: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, String>):
  import "./effs/wire.c"
  import "./effs/wire.js"

# Ends the TLS session and closes the socket.
def tls.close(sock: Socket) -> IO(Unit):
  import "./effs/wire.c"
  import "./effs/wire.js"
