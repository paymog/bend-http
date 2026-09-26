"""Wire benchmark in Python with socket (see README.md)."""
import socket
import threading
import time

PORT = 38475
N = 1_048_576
CHK = 470


def fill(b: bytearray) -> None:
	for i in range(N):
		b[i] = (i * 31 + 7) & 255


def checksum(b: bytes) -> int:
	return b[12345] + b[N - 1]


def server(ready: threading.Event) -> None:
	ls = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	ls.bind(("127.0.0.1", PORT))
	ls.listen(1)
	ready.set()
	conn, _ = ls.accept()
	with conn:
		data = bytearray(N)
		view = memoryview(data)
		off = 0
		while off < N:
			n = conn.recv_into(view[off:], N - off)
			if n == 0:
				raise SystemExit("short read")
			off += n
		conn.sendall(data)
	ls.close()


def main() -> None:
	ready = threading.Event()
	th = threading.Thread(target=server, args=(ready,), daemon=True)
	th.start()
	if not ready.wait(timeout=5):
		raise SystemExit("server timeout")

	buf = bytearray(N)
	fill(buf)

	with socket.create_connection(("127.0.0.1", PORT)) as conn:
		t0 = time.perf_counter()
		conn.sendall(buf)
		print(f"send\t{(time.perf_counter() - t0) * 1000:.3f}\t{CHK}")

		t0 = time.perf_counter()
		got = bytearray(N)
		view = memoryview(got)
		off = 0
		while off < N:
			n = conn.recv_into(view[off:], N - off)
			if n == 0:
				raise SystemExit("short read")
			off += n
		cs = checksum(got)
		print(f"recv\t{(time.perf_counter() - t0) * 1000:.3f}\t{cs}")

	th.join(timeout=5)
	if cs != CHK:
		raise SystemExit(2)


if __name__ == "__main__":
	main()
