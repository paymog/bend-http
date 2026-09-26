// DNS
// ===
// OS resolver for dns/dns.bend lookup effect.

#ifndef DNS_EFFS
#define DNS_EFFS

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>

static u32 dns_gai_code(int gai) {
  switch (gai) {
    case EAI_NONAME:
    case EAI_NODATA:
      return ENOENT;
    case EAI_AGAIN:
      return EAGAIN;
    case EAI_MEMORY:
      return ENOMEM;
    default:
      return EIO;
  }
}

#endif

#ifdef CID(lookup)

static void dns_lookup_call(IoWork* w) {
  struct addrinfo  hints = { 0 };
  struct addrinfo* res   = NULL;
  hints.ai_family        = AF_INET;
  hints.ai_socktype      = SOCK_STREAM;
  int gai = getaddrinfo((char*)w->data, NULL, &hints, &res);
  if (gai != 0) {
    w->code = dns_gai_code(gai);
    w->text = NULL;
    return;
  }
  char buf[INET_ADDRSTRLEN];
  struct sockaddr_in* in = (struct sockaddr_in*)res->ai_addr;
  inet_ntop(AF_INET, &in->sin_addr, buf, sizeof(buf));
  w->text = io_mem(strdup(buf));
  w->code = 0;
  freeaddrinfo(res);
}

static Term dns_lookup_pack(Env e, IoWork* w) {
  Term r = w->code ? io_fail(e, w->code, NULL)
                   : io_done(e, io_str(e, w->text, strlen(w->text)));
  free(w->data);
  if (w->text != NULL) {
    free(w->text);
  }
  return r;
}

Term lookup_run(Env e, Term* f, IoWork* w) {
  w->data = io_cstr(e, f[0], &w->size);
  if (w->data == NULL || io_nul(w->data, w->size)) {
    free(w->data);
    w->data = NULL;
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, dns_lookup_call, dns_lookup_pack);
}

static void __attribute__((constructor)) dns_lookup_use(void) {
  io_eff(CID(lookup), lookup_run, 0);
}

#endif
