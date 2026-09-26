// Wire benchmark in Rust with std::net (see README.md).
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::sync::mpsc;
use std::thread;
use std::time::Instant;

const PORT: u16 = 38501;
const N: usize = 1_048_576;
const R: usize = 64;
const CHK: u32 = 3187671040;

fn fill(b: &mut [u8]) {
	for (i, byte) in b.iter_mut().enumerate() {
		*byte = ((i as u64 * 31 + 7) & 255) as u8;
	}
}

fn hash_buf(mut h: u32, b: &[u8]) -> u32 {
	for &byte in b {
		h = h.wrapping_mul(31).wrapping_add(u32::from(byte));
	}
	h
}

fn addr() -> SocketAddr {
	format!("127.0.0.1:{}", PORT).parse().unwrap()
}

fn main() {
	let (ready_tx, ready_rx) = mpsc::channel();
	let th = thread::spawn(move || {
		let ls = TcpListener::bind(addr()).unwrap();
		ready_tx.send(()).unwrap();
		let (mut conn, _) = ls.accept().unwrap();
		let mut buf = vec![0u8; N];
		for _ in 0..R {
			conn.read_exact(&mut buf).unwrap();
			conn.write_all(&buf).unwrap();
		}
	});
	ready_rx.recv().unwrap();

	let mut buf = vec![0u8; N];
	fill(&mut buf);
	let mut conn = TcpStream::connect(addr()).unwrap();
	let mut cs = 0u32;

	let t0 = Instant::now();
	for _ in 0..R {
		conn.write_all(&buf).unwrap();
		conn.read_exact(&mut buf).unwrap();
		cs = hash_buf(cs, &buf);
	}
	let ms = t0.elapsed().as_secs_f64() * 1000.0;
	println!("echo\t{}\t{}", ms, cs);

	th.join().unwrap();
	if cs != CHK {
		std::process::exit(2);
	}
}
