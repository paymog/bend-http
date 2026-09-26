// HTTP codec benchmark in C with llhttp, Node's parser (see README.md).
#include <llhttp.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define N 20000

static const char REQ[] =
    "POST /api/v1/items?page=2&sort=name HTTP/1.1\r\nHost: example.com\r\n"
    "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\n"
    "Accept: application/json, text/plain, */*\r\nAccept-Language: en-US,en;q=0.9\r\nAccept-Encoding: gzip, deflate, br\r\n"
    "Content-Type: application/json\r\nCookie: session=0123456789abcdef; theme=dark\r\nConnection: keep-alive\r\n"
    "Content-Length: 26\r\n\r\n{\"name\":\"widget\",\"qty\":12}";
static const char RES[] =
    "HTTP/1.1 200 OK\r\nDate: Fri, 25 Sep 2026 12:00:00 GMT\r\nServer: bend-kit\r\n"
    "Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\n"
    "X-Request-Id: 7f3c2a10-5b6e-4d8f-9a1b-2c3d4e5f6a7b\r\n"
    "Content-Length: 34\r\n\r\n{\"id\":42,\"name\":\"widget\",\"qty\":12}";

static uint32_t sum;

// Every span is whole in one buffer, so each callback fires once per span.
static int span(llhttp_t *p, const char *at, size_t len) { sum += len; return 0; }
static int field_done(llhttp_t *p) { sum += 1; return 0; }
static int head_done(llhttp_t *p) { if (p->type == HTTP_RESPONSE) sum += p->status_code; return 0; }

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static void run(const char *name, llhttp_type_t type, const char *msg, size_t len) {
  llhttp_settings_t s;
  llhttp_settings_init(&s);
  s.on_method = s.on_url = s.on_header_field = s.on_header_value = s.on_body = span;
  s.on_header_value_complete = field_done;
  s.on_headers_complete = head_done;
  llhttp_t p;
  llhttp_init(&p, type, &s);
  sum = 0;
  double t0 = now_ms();
  for (int i = 0; i < N; i++) {
    if (llhttp_execute(&p, msg, len) != HPE_OK) { fprintf(stderr, "%s: %s\n", name, llhttp_get_error_reason(&p)); return; }
  }
  printf("%s\t%.1f\t%u\n", name, now_ms() - t0, sum);
}

int main(void) {
  run("parse_req", HTTP_REQUEST, REQ, sizeof REQ - 1);
  run("parse_res", HTTP_RESPONSE, RES, sizeof RES - 1);
  return 0;
}
