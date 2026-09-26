// Wire benchmark in C with raw TCP sockets (see README.md).
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define PORT 38475
#define N 1048576
#define CHK 470

static volatile int ready;

static double now_ms(void) {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static void fill(uint8_t *b) {
	for (size_t i = 0; i < N; i++)
		b[i] = (uint8_t)((i * 31 + 7) & 255);
}

static uint32_t checksum(const uint8_t *b) {
	return (uint32_t)b[12345] + (uint32_t)b[N - 1];
}

static int recv_all(int fd, uint8_t *b, size_t n) {
	size_t got = 0;
	while (got < n) {
		ssize_t r = recv(fd, b + got, n - got, 0);
		if (r <= 0)
			return -1;
		got += (size_t)r;
	}
	return 0;
}

static int send_all(int fd, const uint8_t *b, size_t n) {
	size_t sent = 0;
	while (sent < n) {
		ssize_t r = send(fd, b + sent, n - sent, 0);
		if (r <= 0)
			return -1;
		sent += (size_t)r;
	}
	return 0;
}

static void *server(void *arg) {
	(void)arg;
	int ls = socket(AF_INET, SOCK_STREAM, 0);
	if (ls < 0)
		return NULL;
	int one = 1;
	setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
	struct sockaddr_in addr = {0};
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	addr.sin_port = htons(PORT);
	if (bind(ls, (struct sockaddr *)&addr, sizeof(addr)) < 0 ||
	    listen(ls, 1) < 0) {
		close(ls);
		return NULL;
	}
	ready = 1;
	int conn = accept(ls, NULL, NULL);
	close(ls);
	if (conn < 0)
		return NULL;
	uint8_t *buf = malloc(N);
	if (!buf || recv_all(conn, buf, N) < 0 || send_all(conn, buf, N) < 0) {
		free(buf);
		close(conn);
		return NULL;
	}
	free(buf);
	close(conn);
	return NULL;
}

int main(void) {
	ready = 0;
	pthread_t th;
	if (pthread_create(&th, NULL, server, NULL) != 0)
		return 1;

	uint8_t *buf = malloc(N);
	if (!buf)
		return 1;
	fill(buf);

	while (!ready)
		usleep(1000);

	int fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd < 0)
		return 1;
	struct sockaddr_in addr = {0};
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	addr.sin_port = htons(PORT);
	if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0)
		return 1;

	double t0 = now_ms();
	if (send_all(fd, buf, N) < 0)
		return 1;
	printf("send\t%.3f\t%u\n", now_ms() - t0, CHK);

	t0 = now_ms();
	if (recv_all(fd, buf, N) < 0)
		return 1;
	uint32_t cs = checksum(buf);
	printf("recv\t%.3f\t%u\n", now_ms() - t0, cs);

	close(fd);
	free(buf);
	pthread_join(th, NULL);
	return cs == CHK ? 0 : 2;
}
