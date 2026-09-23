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

#endif

#ifdef CID_RECV

static Term wire_recv_more(Env e, IoWork* w) {
  int fd  = (int)w->hand;
  w->size = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  if (w->code == EAGAIN) {
    return io_wait_on(w, fd, POLLIN, 0, wire_recv_more);
  }
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, wire_bytes(e, w->data, w->size));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term wire_recv_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  return wire_recv_more(e, w);
}

static void __attribute__((constructor)) wire_recv_use(void) {
  io_eff(CID_RECV, wire_recv_run, IO_READ);
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
  w->size = io_sys_end(w, recvfrom(fd, w->data, (size_t)w->made, 0,
    (struct sockaddr*)&at, &alen));
  if (w->code == EAGAIN) {
    return io_wait_on(w, fd, POLLIN, 0, wire_recv_from_more);
  }
  inet_ntop(AF_INET, &at.sin_addr, host, 16);
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, io_tup(e, io_str(e, host, strlen(host)),
      io_tup(e, ntohs(at.sin_port), wire_bytes(e, w->data, w->size))));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

Term wire_recv_from_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  return wire_recv_from_more(e, w);
}

static void __attribute__((constructor)) wire_recv_from_use(void) {
  io_eff(CID_RECV_FROM, wire_recv_from_run, IO_READ);
}

#endif

#ifdef CID_SEND_TO

static Term wire_send_to_more(Env e, IoWork* w) {
  struct sockaddr_in at;
  int     fd = (int)w->hand;
  ssize_t n  = -1;
  errno      = EINVAL;
  if (w->code == 0 && io_sys_addr(w->text, (u32)w->word, &at) == 0) {
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
  w->word = (u32)f[2];
  w->data = wire_octets(e, f[3], &w->size, &bad);
  w->code = bad || io_nul(w->text, hn) ? EINVAL : 0;
  return wire_send_to_more(e, w);
}

static void __attribute__((constructor)) wire_send_to_use(void) {
  io_eff(CID_SEND_TO, wire_send_to_run, 0);
}

#endif
