// Wire
// ====
// JS twins of wire.c: one char code per octet in, each char's low byte out.

function wire_text(b, n) {
  let s = "";
  for (let i = 0; i < n; i += 8192) {
    s += String.fromCharCode.apply(null, b.subarray(i, Math.min(i + 8192, n)));
  }
  return s;
}

// A char above 255 is not an octet; the caller gets EINVAL.
function wire_octets(data) {
  const b = new Uint8Array(data.length);
  for (let i = 0; i < data.length; i += 1) {
    const c = data.charCodeAt(i);
    if (c > 255) {
      return null;
    }
    b[i] = c;
  }
  return b;
}

function recv(socket, max, k) {
  const sys = io_sys();
  const fd = socket;
  const b = new Uint8Array(Math.max(Number(max), 1));
  const again = sys.mac ? 35 : 11;
  const go = () => {
    const n = Number(sys.recv(fd, sys.ptr(b), Number(max), 0));
    if (n < 0) {
      const code = sys.errno();
      if (code === again) {
        io_park_on(fd, false, k, go);
        return undefined;
      }
      return io_tup(socket, io_fail(code));
    }
    return io_tup(socket, io_done(wire_text(b, n)));
  };
  return go();
}

function recv_need() {
  return { read: true };
}

function send(socket, data, k) {
  const sys = io_sys();
  const fd = socket;
  const b = wire_octets(data);
  if (b === null) {
    return io_tup(socket, io_fail(22));
  }
  const again = sys.mac ? 35 : 11;
  const go = (at) => {
    while (at < b.length) {
      const part = b.subarray(at);
      const n = Number(sys.send(fd, sys.ptr(part), part.length, 0));
      if (n < 0) {
        const code = sys.errno();
        if (code === again) {
          io_park_on(fd, true, k, () => go(at));
          return undefined;
        }
        return io_tup(socket, io_fail(code));
      }
      at += n;
    }
    return io_tup(socket, io_done({ $: "Unit" }));
  };
  return go(0);
}

function recv_from(socket, max, k) {
  const sys = io_sys();
  const fd = socket;
  const b = new Uint8Array(Math.max(Number(max), 1));
  const peer = new Uint8Array(16);
  const len = new Uint32Array([16]);
  const go = () => {
    const n = Number(sys.recvfrom(fd, sys.ptr(b), Number(max), 0, sys.ptr(peer),
      sys.ptr(len)));
    if (n < 0) {
      const code = sys.errno();
      if (code === (sys.mac ? 35 : 11)) {
        io_park_on(fd, false, k, go);
        return undefined;
      }
      return io_tup(socket, io_fail(code));
    }
    const host = peer[4] + "." + peer[5] + "." + peer[6] + "." + peer[7];
    const port = (peer[2] << 8) | peer[3];
    return io_tup(socket, io_done(io_tup(host, port, wire_text(b, n))));
  };
  return go();
}

function recv_from_need() {
  return { read: true };
}

function send_to(socket, host, port, data, k) {
  const sys = io_sys();
  const fd = socket;
  const at = io_addr(host, Number(port));
  const b = wire_octets(data);
  if (at === null || b === null) {
    return io_tup(socket, io_fail(22));
  }
  const go = () => {
    const sent = sys.sendto(fd, sys.ptr(b), b.length, 0, sys.ptr(at), 16);
    if (Number(sent) < 0) {
      const code = sys.errno();
      if (code === (sys.mac ? 35 : 11)) {
        io_park_on(fd, true, k, go);
        return undefined;
      }
      return io_tup(socket, io_fail(code));
    }
    return io_tup(socket, io_done({ $: "Unit" }));
  };
  return go();
}
