// Wire
// ====
// Base's socket effects decode and encode UTF-8. These move octets as they
// are: one Char per byte (0..255) in, and each Char's low byte out.

#ifndef WIRE_BYTES
#define WIRE_BYTES

static Term wire_bytes(Env e, const char* p, u64 n) {
  Term s    = term_pak(CID_SNIL, 0);
  Loc  hole = 0;
  for (u64 i = 0; i < n; i += 1) {
    Loc  l = heap_alloc(e, 1);
    Term t = term_ctr(CID_SCON, l);
    e.mem[l] = (uint8_t)p[i];
    if (hole == 0) {
      s = t;
    } else {
      e.mem[hole] = io_seal(e, t, CID_SCON);
    }
    hole = l + 1;
  }
  if (hole != 0) {
    e.mem[hole] = io_seal(e, term_pak(CID_SNIL, 0), CID_SCON);
  }
  return s;
}

// A Char above 255 is not an octet; the send fails with EINVAL.
static char* wire_octets(Env e, Term s, u64* len, bool* bad) {
  u64   cap = 64;
  u64   n   = 0;
  char* buf = io_mem(malloc(cap));
  *bad = false;
  while (term_aux(s) == CID_SCON) {
    Term fb[2];
    spare_free(e, cls_fit(2), ctr_take(e, s, 2, fb));
    if (n + 1 > cap) {
      cap *= 2;
      buf = io_mem(realloc(buf, cap));
    }
    *bad = *bad || (u64)fb[0] > 255;
    buf[n++] = (char)(fb[0] & 0xFF);
    s = fb[1];
  }
  *len = n;
  return buf;
}

// A deadline in io_tick() nanoseconds, or 0 for none.
static u64 wire_deadline(u64 ms) {
  return ms != 0 ? io_tick() + ms * 1000000ull : 0;
}

static bool wire_late(u64 at) {
  return at != 0 && io_tick() >= at;
}

#endif

#ifdef CID_RECV

// Not IO_READ: that would wait for readability before run, with no deadline.
// w->size holds the deadline until the read lands.
static Term wire_recv_more(Env e, IoWork* w) {
  int     fd = (int)w->hand;
  ssize_t n  = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  if (w->code == EAGAIN) {
    if (!wire_late(w->size)) {
      return io_wait_on(w, fd, POLLIN, w->size, wire_recv_more);
    }
    w->code = ETIMEDOUT;
  }
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, wire_bytes(e, w->data, (u64)n));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term wire_recv_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  w->size = wire_deadline((u64)f[2]);
  return wire_recv_more(e, w);
}

static void __attribute__((constructor)) wire_recv_use(void) {
  io_eff(CID_RECV, wire_recv_run, 0);
}

#endif

#ifdef CID_SEND

static Term wire_send_more(Env e, IoWork* w) {
  int fd = (int)w->hand;
  while (w->code == 0 && (u64)w->made < w->size) {
    ssize_t n = send(fd, w->data + w->made, w->size - (u64)w->made, 0);
    if (n < 0 && errno == EAGAIN) {
      return io_wait_on(w, fd, POLLOUT, 0, wire_send_more);
    }
    w->made += io_sys_end(w, n);
  }
  Term r = w->code != 0 ? io_fail(e, w->code, NULL)
    : io_done(e, term_pak(CID_UNIT, 0));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term wire_send_run(Env e, Term* f, IoWork* w) {
  bool bad;
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->data = wire_octets(e, f[1], &w->size, &bad);
  w->made = 0;
  w->code = bad ? EINVAL : 0;
  return wire_send_more(e, w);
}

static void __attribute__((constructor)) wire_send_use(void) {
  io_eff(CID_SEND, wire_send_run, 0);
}

#endif

#ifdef CID_RECV_FROM

static Term wire_recv_from_more(Env e, IoWork* w) {
  struct sockaddr_in at = { 0 };
  socklen_t alen = sizeof(at);
  char      host[16];
  int       fd = (int)w->hand;
  ssize_t   n  = io_sys_end(w, recvfrom(fd, w->data, (size_t)w->made, 0,
    (struct sockaddr*)&at, &alen));
  if (w->code == EAGAIN) {
    if (!wire_late(w->size)) {
      return io_wait_on(w, fd, POLLIN, w->size, wire_recv_from_more);
    }
    w->code = ETIMEDOUT;
  }
  inet_ntop(AF_INET, &at.sin_addr, host, 16);
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, io_tup(e, io_str(e, host, strlen(host)),
      io_tup(e, ntohs(at.sin_port), wire_bytes(e, w->data, (u64)n))));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term wire_recv_from_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  w->size = wire_deadline((u64)f[2]);
  return wire_recv_from_more(e, w);
}

static void __attribute__((constructor)) wire_recv_from_use(void) {
  io_eff(CID_RECV_FROM, wire_recv_from_run, 0);
}

#endif

#ifdef CID_SEND_TO

static Term wire_send_to_more(Env e, IoWork* w) {
  struct sockaddr_in at;
  int     fd = (int)w->hand;
  ssize_t n  = -1;
  errno      = EINVAL;
  if (w->code == 0 && io_sys_addr(w->text, (u32)w->made, &at) == 0) {
    n = sendto(fd, w->data, w->size, 0, (struct sockaddr*)&at, sizeof(at));
  }
  io_sys_end(w, n);
  if (w->code == EAGAIN) {
    return io_wait_on(w, fd, POLLOUT, 0, wire_send_to_more);
  }
  Term r = w->code != 0 ? io_fail(e, w->code, NULL)
    : io_done(e, term_pak(CID_UNIT, 0));
  free(w->text);
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term wire_send_to_run(Env e, Term* f, IoWork* w) {
  uint64_t hn = 0;
  bool     bad;
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->text = io_cstr(e, f[1], &hn);
  w->made = (intptr_t)f[2];
  w->data = wire_octets(e, f[3], &w->size, &bad);
  w->code = bad || io_nul(w->text, hn) ? EINVAL : 0;
  return wire_send_to_more(e, w);
}

static void __attribute__((constructor)) wire_send_to_use(void) {
  io_eff(CID_SEND_TO, wire_send_to_run, 0);
}

#endif

#ifdef CID_CONNECT

// Base's TCP.connect waits as long as the kernel does (~75 s); this one has a
// deadline. On each wake SO_ERROR reports a failure, and connect() again says
// EALREADY (still going) or EISCONN (done).
static Term wire_connect_end(Env e, IoWork* w, int err) {
  int fd = (int)w->hand;
  if (err != 0 && fd >= 0) {
    close(fd);
  }
  free(w->data);
  return err != 0 ? io_fail(e, (u32)err, NULL) : io_done(e, io_hand(fd));
}

static Term wire_connect_more(Env e, IoWork* w) {
  struct sockaddr_in at;
  int       fd  = (int)w->hand;
  int       err = 0;
  socklen_t len = sizeof(err);
  if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len) != 0) {
    err = errno;
  }
  if (err == 0) {
    io_sys_addr(w->data, (u32)w->made, &at);
    err = connect(fd, (struct sockaddr*)&at, sizeof(at)) == 0 ? 0 : errno;
  }
  if (err == 0 || err == EISCONN) {
    return wire_connect_end(e, w, 0);
  }
  if (err == EINPROGRESS || err == EALREADY) {
    if (!wire_late(w->size)) {
      return io_wait_on(w, fd, POLLOUT, w->size, wire_connect_more);
    }
    err = ETIMEDOUT;
  }
  return wire_connect_end(e, w, err);
}

Term connect_run(Env e, Term* f, IoWork* w) {
  struct sockaddr_in at;
  u64 hn  = 0;
  w->data = io_cstr(e, f[0], &hn);
  w->made = (intptr_t)f[1];
  w->hand = -1;
  if (io_nul(w->data, hn) || io_sys_addr(w->data, (u32)w->made, &at) != 0) {
    return wire_connect_end(e, w, EINVAL);
  }
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return wire_connect_end(e, w, errno);
  }
  w->hand = fd;
  if (fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) {
    return wire_connect_end(e, w, errno);
  }
  w->size = wire_deadline((u64)f[2]);
  return wire_connect_more(e, w);
}

static void __attribute__((constructor)) connect_use(void) {
  io_eff(CID_CONNECT, connect_run, 0);
}

#endif

// TLS
// ===
// OpenSSL 3, loaded at run time (bend links no extra libraries). The SSL
// object of a socket lives in a table keyed by its fd. Peer verification
// (chain + host name) is always on; TLS 1.2 is the floor.

#if defined(CID_TLS_CONNECT) || defined(CID_TLS_SEND) || defined(CID_TLS_RECV) || defined(CID_TLS_CLOSE)
#ifndef WIRE_TLS
#define WIRE_TLS
#include <dlfcn.h>

typedef struct {
  int   state;
  void* ctx;
  void* (*ssl_new)(void*);
  int   (*set_fd)(void*, int);
  long  (*ctrl)(void*, int, long, void*);
  int   (*set1_host)(void*, const char*);
  int   (*connect)(void*);
  int   (*read)(void*, void*, int);
  int   (*write)(void*, const void*, int);
  int   (*get_error)(const void*, int);
  int   (*shutdown)(void*);
  void  (*ssl_free)(void*);
  long  (*verify_result)(const void*);
  const char* (*verify_text)(long);
} WireTls;

#define WIRE_TLS_FDS 65536
static WireTls wire_tls;
static void*   wire_tls_ssl[WIRE_TLS_FDS];

static void* wire_tls_open(void) {
  const char* paths[] = { getenv("BEND_LIBSSL"),
    "/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib",
    "/usr/local/opt/openssl@3/lib/libssl.3.dylib", "libssl.3.dylib", "libssl.so.3" };
  for (u64 i = 0; i < sizeof(paths) / sizeof(paths[0]); i += 1) {
    void* h = paths[i] != NULL ? dlopen(paths[i], RTLD_NOW | RTLD_LOCAL) : NULL;
    if (h != NULL) {
      return h;
    }
  }
  return NULL;
}

static bool wire_tls_load(void) {
  if (wire_tls.state != 0) {
    return wire_tls.state > 0;
  }
  wire_tls.state = -1;
  void* h = wire_tls_open();
  if (h == NULL) {
    return false;
  }
  void* (*method)(void)                 = dlsym(h, "TLS_client_method");
  void* (*ctx_new)(void*)               = dlsym(h, "SSL_CTX_new");
  int   (*paths)(void*)                 = dlsym(h, "SSL_CTX_set_default_verify_paths");
  void  (*verify)(void*, int, void*)    = dlsym(h, "SSL_CTX_set_verify");
  long  (*ctx_ctrl)(void*, int, long, void*) = dlsym(h, "SSL_CTX_ctrl");
  uint64_t (*options)(void*, uint64_t)  = dlsym(h, "SSL_CTX_set_options");
  wire_tls.ssl_new       = dlsym(h, "SSL_new");
  wire_tls.set_fd        = dlsym(h, "SSL_set_fd");
  wire_tls.ctrl          = dlsym(h, "SSL_ctrl");
  wire_tls.set1_host     = dlsym(h, "SSL_set1_host");
  wire_tls.connect       = dlsym(h, "SSL_connect");
  wire_tls.read          = dlsym(h, "SSL_read");
  wire_tls.write         = dlsym(h, "SSL_write");
  wire_tls.get_error     = dlsym(h, "SSL_get_error");
  wire_tls.shutdown      = dlsym(h, "SSL_shutdown");
  wire_tls.ssl_free      = dlsym(h, "SSL_free");
  wire_tls.verify_result = dlsym(h, "SSL_get_verify_result");
  wire_tls.verify_text   = dlsym(h, "X509_verify_cert_error_string");
  if (!method || !ctx_new || !paths || !verify || !ctx_ctrl || !options
    || !wire_tls.ssl_new || !wire_tls.set_fd || !wire_tls.ctrl
    || !wire_tls.set1_host || !wire_tls.connect || !wire_tls.read
    || !wire_tls.write || !wire_tls.get_error || !wire_tls.shutdown
    || !wire_tls.ssl_free || !wire_tls.verify_result || !wire_tls.verify_text) {
    return false;
  }
  void* ctx = ctx_new(method());
  if (ctx == NULL || paths(ctx) != 1) {
    return false;
  }
  verify(ctx, 1, NULL);              // SSL_VERIFY_PEER
  ctx_ctrl(ctx, 123, 0x0303, NULL);  // SSL_CTRL_SET_MIN_PROTO_VERSION, TLS 1.2
  options(ctx, 1ull << 7);           // SSL_OP_IGNORE_UNEXPECTED_EOF: a bare EOF reads as close
  wire_tls.ctx   = ctx;
  wire_tls.state = 1;
  return true;
}

static void* wire_tls_of(int fd) {
  return fd >= 0 && fd < WIRE_TLS_FDS ? wire_tls_ssl[fd] : NULL;
}

static void wire_tls_drop(int fd) {
  void* ssl = wire_tls_of(fd);
  if (ssl != NULL) {
    wire_tls.ssl_free(ssl);
    wire_tls_ssl[fd] = NULL;
  }
}

#endif
#endif

#ifdef CID_TLS_CONNECT

static Term wire_tls_connect_end(Env e, IoWork* w, Term r) {
  free(w->text);
  return io_tup(e, io_hand(w->hand), r);
}

static Term wire_tls_connect_fail(Env e, IoWork* w, u32 code, const char* why) {
  wire_tls_drop((int)w->hand);
  return wire_tls_connect_end(e, w, io_fail(e, code, why));
}

static Term wire_tls_connect_more(Env e, IoWork* w) {
  int   fd  = (int)w->hand;
  void* ssl = wire_tls_of(fd);
  int   r   = wire_tls.connect(ssl);
  if (r == 1) {
    return wire_tls_connect_end(e, w, io_done(e, term_pak(CID_UNIT, 0)));
  }
  int err = wire_tls.get_error(ssl, r);
  if (err == 2 || err == 3) {  // SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE
    if (!wire_late(w->size)) {
      return io_wait_on(w, fd, err == 2 ? POLLIN : POLLOUT, w->size, wire_tls_connect_more);
    }
    return wire_tls_connect_fail(e, w, ETIMEDOUT, NULL);
  }
  long v = wire_tls.verify_result(ssl);
  return wire_tls_connect_fail(e, w, EPROTO, v != 0 ? wire_tls.verify_text(v) : "TLS handshake failed");
}

Term tls_connect_run(Env e, Term* f, IoWork* w) {
  uint64_t hn = 0;
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->text = io_cstr(e, f[1], &hn);
  w->size = wire_deadline((u64)f[2]);
  int fd  = (int)w->hand;
  if (!wire_tls_load()) {
    return wire_tls_connect_end(e, w, io_fail(e, ENOENT, "TLS needs OpenSSL 3 (libssl.3); set BEND_LIBSSL to its path"));
  }
  if (fd < 0 || fd >= WIRE_TLS_FDS || io_nul(w->text, hn)) {
    return wire_tls_connect_end(e, w, io_fail(e, EINVAL, NULL));
  }
  void* ssl = wire_tls.ssl_new(wire_tls.ctx);
  if (ssl == NULL) {
    return wire_tls_connect_end(e, w, io_fail(e, ENOMEM, NULL));
  }
  wire_tls_ssl[fd] = ssl;
  // SNI (SSL_CTRL_SET_TLSEXT_HOSTNAME, host_name) and host name verification.
  if (wire_tls.set_fd(ssl, fd) != 1 || wire_tls.ctrl(ssl, 55, 0, w->text) != 1
    || wire_tls.set1_host(ssl, w->text) != 1) {
    return wire_tls_connect_fail(e, w, EPROTO, "TLS setup failed");
  }
  return wire_tls_connect_more(e, w);
}

static void __attribute__((constructor)) tls_connect_use(void) {
  io_eff(CID_TLS_CONNECT, tls_connect_run, 0);
}

#endif

#ifdef CID_TLS_SEND

// SSL_write is retried with the same buffer, as OpenSSL requires.
static Term wire_tls_send_more(Env e, IoWork* w) {
  int   fd  = (int)w->hand;
  void* ssl = wire_tls_of(fd);
  while (w->code == 0 && (u64)w->made < w->size) {
    if (ssl == NULL) {
      w->code = EBADF;
      break;
    }
    u64 left = w->size - (u64)w->made;
    int n    = wire_tls.write(ssl, w->data + w->made, left > INT32_MAX ? INT32_MAX : (int)left);
    if (n > 0) {
      w->made += n;
      continue;
    }
    int err = wire_tls.get_error(ssl, n);
    if (err == 2 || err == 3) {
      return io_wait_on(w, fd, err == 2 ? POLLIN : POLLOUT, 0, wire_tls_send_more);
    }
    w->code = EPIPE;
  }
  Term r = w->code != 0 ? io_fail(e, w->code, NULL)
    : io_done(e, term_pak(CID_UNIT, 0));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term tls_send_run(Env e, Term* f, IoWork* w) {
  bool bad;
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->data = wire_octets(e, f[1], &w->size, &bad);
  w->made = 0;
  w->code = bad ? EINVAL : 0;
  return wire_tls_send_more(e, w);
}

static void __attribute__((constructor)) tls_send_use(void) {
  io_eff(CID_TLS_SEND, tls_send_run, 0);
}

#endif

#ifdef CID_TLS_RECV

// "" means the peer closed (close_notify, or a bare EOF).
static Term wire_tls_recv_more(Env e, IoWork* w) {
  int   fd  = (int)w->hand;
  void* ssl = wire_tls_of(fd);
  int   n   = ssl != NULL ? wire_tls.read(ssl, w->data, (int)w->made) : -1;
  Term  r;
  if (n > 0) {
    r = io_done(e, wire_bytes(e, w->data, (u64)n));
  } else {
    int err = ssl != NULL ? wire_tls.get_error(ssl, n) : 1;
    if (err == 2 || err == 3) {
      if (!wire_late(w->size)) {
        return io_wait_on(w, fd, err == 2 ? POLLIN : POLLOUT, w->size, wire_tls_recv_more);
      }
      err = -1;
    }
    r = err == 6 ? io_done(e, term_pak(CID_SNIL, 0))  // SSL_ERROR_ZERO_RETURN
      : err == -1 ? io_fail(e, ETIMEDOUT, NULL)
      : io_fail(e, ssl != NULL ? EIO : EBADF, ssl != NULL ? "TLS read failed" : NULL);
  }
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term tls_recv_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  w->size = wire_deadline((u64)f[2]);
  return wire_tls_recv_more(e, w);
}

static void __attribute__((constructor)) tls_recv_use(void) {
  io_eff(CID_TLS_RECV, tls_recv_run, 0);
}

#endif

#ifdef CID_TLS_CLOSE

// ponytail: one non-blocking close_notify attempt; no wait for the peer's
Term tls_close_run(Env e, Term* f, IoWork* w) {
  int   fd  = (int)io_hand_v(f[0]);
  void* ssl = wire_tls_of(fd);
  if (ssl != NULL) {
    wire_tls.shutdown(ssl);
    wire_tls_drop(fd);
  }
  close(fd);
  return term_pak(CID_UNIT, 0);
}

static void __attribute__((constructor)) tls_close_use(void) {
  io_eff(CID_TLS_CLOSE, tls_close_run, 0);
}

#endif
