// HTTP codec benchmark in Rust with httparse (see ../README.md).
use std::hint::black_box;
use std::time::Instant;

const N: usize = 20000;
const REQ: &[u8] = b"POST /api/v1/items?page=2&sort=name HTTP/1.1\r\nHost: example.com\r\n\
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\n\
Accept: application/json, text/plain, */*\r\nAccept-Language: en-US,en;q=0.9\r\nAccept-Encoding: gzip, deflate, br\r\n\
Content-Type: application/json\r\nCookie: session=0123456789abcdef; theme=dark\r\nConnection: keep-alive\r\n\
Content-Length: 26\r\n\r\n{\"name\":\"widget\",\"qty\":12}";
const RES: &[u8] = b"HTTP/1.1 200 OK\r\nDate: Fri, 25 Sep 2026 12:00:00 GMT\r\nServer: bend-kit\r\n\
Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\n\
X-Request-Id: 7f3c2a10-5b6e-4d8f-9a1b-2c3d4e5f6a7b\r\n\
Content-Length: 34\r\n\r\n{\"id\":42,\"name\":\"widget\",\"qty\":12}";

// httparse stops at the blank line; the body is the Content-Length bytes after it.
fn fields_and_body(headers: &[httparse::Header], buf: &[u8], off: usize) -> usize {
    let mut s = 0;
    let mut cl = 0;
    for h in headers {
        s += h.name.len() + h.value.len() + 1;
        if h.name.eq_ignore_ascii_case("content-length") {
            cl = std::str::from_utf8(h.value).unwrap().parse().unwrap();
        }
    }
    s + buf[off..off + cl].len()
}

fn parse_req(buf: &[u8]) -> usize {
    let mut hs = [httparse::EMPTY_HEADER; 32];
    let mut r = httparse::Request::new(&mut hs);
    let off = r.parse(buf).unwrap().unwrap();
    r.method.unwrap().len() + r.path.unwrap().len() + fields_and_body(r.headers, buf, off)
}

fn parse_res(buf: &[u8]) -> usize {
    let mut hs = [httparse::EMPTY_HEADER; 32];
    let mut r = httparse::Response::new(&mut hs);
    let off = r.parse(buf).unwrap().unwrap();
    r.code.unwrap() as usize + fields_and_body(r.headers, buf, off)
}

fn run(name: &str, f: fn(&[u8]) -> usize, msg: &[u8]) {
    let t0 = Instant::now();
    let mut s: u32 = 0;
    for _ in 0..N {
        s = s.wrapping_add(f(black_box(msg)) as u32);
    }
    println!("{name}\t{:.1}\t{s}", t0.elapsed().as_secs_f64() * 1e3);
}

fn main() {
    run("parse_req", parse_req, REQ);
    run("parse_res", parse_res, RES);
}
