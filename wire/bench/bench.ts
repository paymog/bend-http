// Wire benchmark in JavaScript with node:net (see README.md).
import { createConnection, createServer, type Socket } from "node:net";

const PORT = 38475;
const N = 1_048_576;
const CHK = 470;

function fill(b: Uint8Array): void {
  for (let i = 0; i < N; i++) b[i] = (i * 31 + 7) & 255;
}

function checksum(b: Uint8Array): number {
  return b[12345] + b[N - 1];
}

function readExact(sock: Socket, n: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const out = Buffer.alloc(n);
    let off = 0;
    const onData = (c: Buffer) => {
      c.copy(out, off);
      off += c.length;
      if (off >= n) {
        sock.off("data", onData);
        sock.off("error", reject);
        resolve(out);
      }
    };
    sock.on("data", onData);
    sock.on("error", reject);
  });
}

function writeAll(sock: Socket, buf: Buffer): Promise<void> {
  return new Promise((resolve, reject) => {
    sock.write(buf, (err) => (err ? reject(err) : resolve()));
  });
}

async function main(): Promise<void> {
  const ready = Promise.withResolvers<void>();
  const srv = createServer(async (conn) => {
    const data = await readExact(conn, N);
    await writeAll(conn, data);
    conn.end();
  });
  srv.on("error", (e) => ready.reject(e));
  srv.listen(PORT, "127.0.0.1", () => ready.resolve());
  await ready.promise;

  const raw = new Uint8Array(N);
  fill(raw);
  const buf = Buffer.from(raw.buffer, raw.byteOffset, raw.byteLength);

  await new Promise<void>((resolve, reject) => {
    const conn = createConnection({ host: "127.0.0.1", port: PORT }, async () => {
      try {
        let t0 = performance.now();
        await writeAll(conn, buf);
        console.log(`send\t${(performance.now() - t0).toFixed(3)}\t${CHK}`);

        t0 = performance.now();
        const got = await readExact(conn, N);
        const cs = checksum(new Uint8Array(got.buffer, got.byteOffset, got.byteLength));
        console.log(`recv\t${(performance.now() - t0).toFixed(3)}\t${cs}`);
        conn.end();
        srv.close();
        if (cs !== CHK) reject(new Error("checksum"));
        else resolve();
      } catch (e) {
        reject(e);
      }
    });
    conn.on("error", reject);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
