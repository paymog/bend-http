// DNS benchmark in C with libresolv: res_mkquery builds, ns_parserr parses. See README.md.
#include <arpa/nameser.h>
#include <resolv.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static const unsigned char TAIL[] = {
    0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0,
    3, 'w', 'w', 'w', 7, 'e', 'x', 'a', 'm', 'p', 'l', 'e', 3, 'c', 'o', 'm', 0, 0, 1, 0, 1,
    0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 0x3c, 0, 4, 93, 184, 216, 34};

static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static uint32_t sum(const unsigned char *p, int n, uint32_t acc) {
    for (int i = 0; i < n; i++) acc += p[i];
    return acc;
}

// The first A/IN record's address as dotted text, like Dns.answer. Returns its length, or -1.
static int answer(unsigned id, const unsigned char *msg, int len, char *out) {
    ns_msg h;
    ns_rr rr;
    if (ns_initparse(msg, len, &h) < 0 || ns_msg_id(h) != id) return -1;
    if (!ns_msg_getflag(h, ns_f_qr) || ns_msg_getflag(h, ns_f_opcode) || ns_msg_getflag(h, ns_f_tc) ||
        ns_msg_getflag(h, ns_f_rcode))
        return -1;
    for (int k = 0; k < ns_msg_count(h, ns_s_an); k++) {
        if (ns_parserr(&h, ns_s_an, k, &rr) < 0) return -1;
        if (ns_rr_type(rr) == ns_t_a && ns_rr_class(rr) == ns_c_in && ns_rr_rdlen(rr) == 4) {
            const unsigned char *a = ns_rr_rdata(rr);
            return snprintf(out, 16, "%u.%u.%u.%u", a[0], a[1], a[2], a[3]);
        }
    }
    return -1;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 100000;
    unsigned char buf[512], msg[sizeof TAIL + 2];
    char ip[16];
    res_init();

    double t0 = now_ms();
    uint32_t chk = 0;
    for (int i = 0; i < n; i++) {
        int len = res_mkquery(ns_o_query, "www.example.com", ns_c_in, ns_t_a, NULL, 0, NULL, buf, sizeof buf);
        if (len < 0) return 1;
        buf[0] = (i >> 8) & 255;
        buf[1] = i & 255;
        chk = sum(buf, len, chk);
    }
    printf("build\t%.1f\t%u\n", now_ms() - t0, chk);

    memcpy(msg + 2, TAIL, sizeof TAIL);
    t0 = now_ms();
    chk = 0;
    for (int i = 0; i < n; i++) {
        unsigned id = i & 0xffff;
        msg[0] = id >> 8;
        msg[1] = id & 255;
        int len = answer(id, msg, sizeof msg, ip);
        if (len > 0) chk = sum((unsigned char *)ip, len, chk);
    }
    printf("parse\t%.1f\t%u\n", now_ms() - t0, chk);
}
