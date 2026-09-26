// Wire benchmark in JavaScript with node:net (see README.md).
import { createConnection, createServer, type Socket } from "node:net";

const PORT = 38501;
const N = 1_048_576;
const R = 64;
const CHK = 3187671040;

function fill(b: Uint8Array): void {
  for (let i = 0; i < N; i++) b[i] = (i * 31 + 7) & 255;
}

function hashBuf(h: number, b: Uint8Array): number {
  for (let i = 0; i < b.length; i++) h = (Math.imul(h, 31) + b[i]) >>> 0;
  return h >>> 0;
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
  const srv = createServer((conn) => {
    (async () => {
      for (let r = 0; r < R; r++) {
        const data = await readExact(conn, N);
        await writeAll(conn, data);
      }
      conn.end();
    })().catch(() => conn.destroy());
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
        let cs = 0;
        const t0 = performance.now();
        for (let r = 0; r < R; r++) {
          await writeAll(conn, buf);
          const got = await readExact(conn, N);
          cs = hashBuf(cs, new Uint8Array(got.buffer, got.byteOffset, got.byteLength));
        }
        const ms = performance.now() - t0;
        console.log(`echo\t${ms.toFixed(3)}\t${cs}`);
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
