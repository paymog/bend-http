// DNS
// ===
// JS twin of dns.c: OS resolver (dscacheutil on macOS, getent on Linux).
// Node dns.lookup is async; Bend can park and resume via k (wire.js, process.js).
// Bun io_run blocks in select without running dns callbacks, so this uses sync OS tools.

function dns_name(host) {
  const b = io_bytes(host);
  if (b.includes(0)) {
    return null;
  }
  return b.length === 0 ? "" : Buffer.from(b).toString("utf8");
}

function dns_first_ip(text) {
  for (const line of text.split("\n")) {
    const m = line.match(/^ip_address: ([0-9.]+)$/);
    if (m) {
      return m[1];
    }
  }
  const line = text.trim().split("\n")[0];
  const field = line.trim().split(/\s+/)[0];
  return /^[0-9.]+$/.test(field) ? field : null;
}

function lookup(host) {
  const name = dns_name(host);
  if (name === null) {
    return io_fail(22);
  }
  const cmd = process.platform === "darwin"
    ? ["/usr/bin/dscacheutil", "-q", "host", "-a", "name", name]
    : ["/usr/bin/getent", "ahostsv4", name];
  try {
    const r = Bun.spawnSync({ cmd, stdout: "pipe", stderr: "pipe" });
    if (r.exitCode !== 0) {
      return io_fail(2);
    }
    const ip = dns_first_ip(new TextDecoder().decode(r.stdout));
    if (ip === null) {
      return io_fail(2);
    }
    return io_done(ip);
  } catch (e) {
    return io_fail(5);
  }
}

io_eff(CID(lookup), lookup);
