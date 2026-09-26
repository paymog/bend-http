// Wire benchmark in Rust with std::net (see README.md).
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::sync::mpsc;
use std::thread;
use std::time::Instant;

const PORT: u16 = 38475;
const N: usize = 1_048_576;
const CHK: u32 = 470;

fn fill(b: &mut [u8]) {
	for (i, byte) in b.iter_mut().enumerate() {
		*byte = ((i as u64 * 31 + 7) & 255) as u8;
	}
}

fn checksum(b: &[u8]) -> u32 {
	b[12345] as u32 + b[N - 1] as u32
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
		conn.read_exact(&mut buf).unwrap();
		conn.write_all(&buf).unwrap();
	});
	ready_rx.recv().unwrap();

	let mut buf = vec![0u8; N];
	fill(&mut buf);

	let mut conn = TcpStream::connect(addr()).unwrap();

	let t0 = Instant::now();
	conn.write_all(&buf).unwrap();
	println!("send\t{}\t{}", t0.elapsed().as_secs_f64() * 1000.0, CHK);

	let t0 = Instant::now();
	conn.read_exact(&mut buf).unwrap();
	let cs = checksum(&buf);
	println!("recv\t{}\t{}", t0.elapsed().as_secs_f64() * 1000.0, cs);

	th.join().unwrap();
	if cs != CHK {
		std::process::exit(2);
	}
}
