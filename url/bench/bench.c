/* URL benchmark in C: origin-form parse and encode (see README.md). */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define ROUNDS 10000

static const char *URLS[] = {
    "/",
    "/health",
    "/users",
    "/users/42",
    "/users/42/posts",
    "/users/42/posts/99",
    "/api/v1/items?page=2&sort=name",
    "/x?a=1&b=2",
    "/a%20b",
    "/a%20b?q=hello%20world",
    "/orgs/paymog/repos/bend-kit/issues/74",
    "/search?q=hello+world&limit=10",
    "/file/name%2Fwith%2Fslashes",
    "/?empty=",
    "/path?u=%2Fenc%2Foded",
    "nope",
};
static const int NURLS = (int)(sizeof(URLS) / sizeof(URLS[0]));

typedef struct {
    char *path;
    char *keys[32];
    char *vals[32];
    int nq;
} Sample;

static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static uint32_t chk_bytes(const char *s) {
    uint32_t h = 0;
    uint32_t n = 0;
    for (; *s; s++) {
        h = h * 31u + (unsigned char)*s;
        n++;
    }
    return h + n;
}

static int unreserved(int c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
           c == '-' || c == '.' || c == '_' || c == '~';
}

static int path_ok(int c) { return unreserved(c) || c == '/'; }

static int hex(int c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static char *pct_decode(const char *in) {
    size_t n = strlen(in);
    char *out = malloc(n + 1);
    if (!out) return NULL;
    size_t w = 0;
    for (size_t i = 0; i < n; i++) {
        if (in[i] == '%' && i + 2 < n) {
            int hi = hex(in[i + 1]), lo = hex(in[i + 2]);
            if (hi >= 0 && lo >= 0) {
                out[w++] = (char)(hi * 16 + lo);
                i += 2;
                continue;
            }
        }
        out[w++] = in[i];
    }
    out[w] = '\0';
    return out;
}

static char *pct_encode(const char *in, int (*ok)(int)) {
    static const char H[] = "0123456789ABCDEF";
    size_t n = strlen(in);
    char *out = malloc(n * 3 + 1);
    if (!out) return NULL;
    size_t w = 0;
    for (size_t i = 0; i < n; i++) {
        unsigned char c = (unsigned char)in[i];
        if (ok(c)) {
            out[w++] = (char)c;
            continue;
        }
        out[w++] = '%';
        out[w++] = H[c >> 4];
        out[w++] = H[c & 15];
    }
    out[w] = '\0';
    return out;
}

static int cmp_str(const void *a, const void *b) {
    return strcmp(*(const char *const *)a, *(const char *const *)b);
}

static Sample *parse_origin(const char *s) {
    if (s[0] != '/') return NULL;
    Sample *u = calloc(1, sizeof(Sample));
    if (!u) return NULL;
    const char *qm = strchr(s, '?');
    if (!qm) {
        u->path = pct_decode(s);
        return u;
    }
    char pathbuf[512];
    size_t plen = (size_t)(qm - s);
    if (plen >= sizeof(pathbuf)) {
        free(u);
        return NULL;
    }
    memcpy(pathbuf, s, plen);
    pathbuf[plen] = '\0';
    u->path = pct_decode(pathbuf);
    char qbuf[1024];
    if (strlen(qm + 1) >= sizeof(qbuf)) {
        free(u->path);
        free(u);
        return NULL;
    }
    strcpy(qbuf, qm + 1);
    char *save = NULL;
    for (char *part = strtok_r(qbuf, "&", &save); part; part = strtok_r(NULL, "&", &save)) {
        if (u->nq >= 32) break;
        char *eq = strchr(part, '=');
        if (eq) {
            *eq = '\0';
            u->keys[u->nq] = pct_decode(part);
            u->vals[u->nq] = pct_decode(eq + 1);
        } else {
            u->keys[u->nq] = pct_decode(part);
            u->vals[u->nq] = strdup("");
        }
        u->nq++;
    }
    return u;
}

static void free_sample(Sample *u) {
    if (!u) return;
    free(u->path);
    for (int i = 0; i < u->nq; i++) {
        free(u->keys[i]);
        free(u->vals[i]);
    }
    free(u);
}

static char *encode_origin(Sample *u) {
    char *path = pct_encode(u->path, path_ok);
    if (!path) return NULL;
    if (u->nq == 0) return path;
    const char *keys[32];
    for (int i = 0; i < u->nq; i++) keys[i] = u->keys[i];
    qsort((void *)keys, (size_t)u->nq, sizeof(keys[0]), cmp_str);
    size_t cap = strlen(path) + (size_t)u->nq * 128 + 2;
    char *out = malloc(cap);
    if (!out) {
        free(path);
        return NULL;
    }
    snprintf(out, cap, "%s?", path);
    free(path);
    int first = 1;
    for (int i = 0; i < u->nq; i++) {
        const char *k = keys[i];
        const char *v = "";
        for (int j = 0; j < u->nq; j++)
            if (strcmp(u->keys[j], k) == 0) {
                v = u->vals[j];
                break;
            }
        char *ek = pct_encode(k, unreserved);
        char *ev = pct_encode(v, unreserved);
        if (!ek || !ev) {
            free(ek);
            free(ev);
            free(out);
            return NULL;
        }
        size_t need = strlen(out) + strlen(ek) + strlen(ev) + 2;
        if (need >= cap) break;
        if (!first) strcat(out, "&");
        first = 0;
        strcat(out, ek);
        strcat(out, "=");
        strcat(out, ev);
        free(ek);
        free(ev);
    }
    return out;
}

static uint32_t score(Sample *u) {
    if (!u) return 0;
    uint32_t s = (uint32_t)strlen(u->path);
    for (int i = 0; i < u->nq; i++) s += (uint32_t)(strlen(u->keys[i]) + strlen(u->vals[i]) + 1);
    return s;
}

static uint32_t parse_round(void) {
    uint32_t acc = 0;
    for (int r = 0; r < ROUNDS; r++)
        for (int i = 0; i < NURLS; i++) {
            Sample *u = parse_origin(URLS[i]);
            acc += score(u);
            free_sample(u);
        }
    return acc;
}

static uint32_t encode_round(Sample **samples, int ns) {
    uint32_t acc = 0;
    for (int r = 0; r < ROUNDS; r++)
        for (int i = 0; i < ns; i++) {
            char *enc = encode_origin(samples[i]);
            if (enc) {
                acc += chk_bytes(enc);
                free(enc);
            }
        }
    return acc;
}

int main(void) {
    Sample *samples[32];
    int ns = 0;
    for (int i = 0; i < NURLS; i++) {
        Sample *u = parse_origin(URLS[i]);
        if (u) samples[ns++] = u;
    }

    double t0 = now_ms();
    uint32_t pchk = parse_round();
    printf("parse\t%.3f\t%u\n", now_ms() - t0, pchk);

    t0 = now_ms();
    uint32_t echk = encode_round(samples, ns);
    printf("encode\t%.3f\t%u\n", now_ms() - t0, echk);

    for (int i = 0; i < ns; i++) free_sample(samples[i]);
    return 0;
}

