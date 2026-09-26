"""Wire benchmark in Python with socket (see README.md)."""
import socket
import threading
import time

PORT = 38501
N = 1_048_576
R = 64
CHK = 3187671040


def fill(b: bytearray) -> None:
	for i in range(N):
		b[i] = (i * 31 + 7) & 255


def hash_buf(h: int, b: bytes) -> int:
	for byte in b:
		h = (h * 31 + byte) & 0xFFFFFFFF
	return h


def server(ready: threading.Event) -> None:
	ls = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	ls.bind(("127.0.0.1", PORT))
	ls.listen(1)
	ready.set()
	conn, _ = ls.accept()
	with conn:
		for _ in range(R):
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
	cs = 0

	with socket.create_connection(("127.0.0.1", PORT)) as conn:
		t0 = time.perf_counter()
		for _ in range(R):
			conn.sendall(buf)
			got = bytearray(N)
			view = memoryview(got)
			off = 0
			while off < N:
				n = conn.recv_into(view[off:], N - off)
				if n == 0:
					raise SystemExit("short read")
				off += n
			cs = hash_buf(cs, got)
		ms = (time.perf_counter() - t0) * 1000
		print(f"echo\t{ms:.3f}\t{cs}")

	th.join(timeout=30)
	if cs != CHK:
		raise SystemExit(2)


if __name__ == "__main__":
	main()
