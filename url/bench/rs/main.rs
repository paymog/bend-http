// URL benchmark in Rust with the url crate (see ../README.md).
use std::time::Instant;
use percent_encoding::{utf8_percent_encode, AsciiSet, NON_ALPHANUMERIC};
use url::Url;

const ROUNDS: u32 = 10000;
const BASE: &str = "http://x";
const URLS: &[&str] = &[
    "/",
    "/health",
    "/users",
    "/users/42",
    "/users/42/posts",
    "/users/42/posts/99",
    "/api/v1/items?page=2&sort=name",
    "/x?a=1&b=2",
    "/a%20b",
    "/a%20b?q=hello%20world",
    "/orgs/paymog/repos/bend-kit/issues/74",
    "/search?q=hello+world&limit=10",
    "/file/name%2Fwith%2Fslashes",
    "/?empty=",
    "/path?u=%2Fenc%2Foded",
    "nope",
];

#[derive(Clone)]
struct Sample {
    path: String,
    q: Vec<(String, String)>,
}

const PATH_SET: &AsciiSet = &NON_ALPHANUMERIC
    .remove(b'/')
    .remove(b'-')
    .remove(b'.')
    .remove(b'_')
    .remove(b'~');

const QUERY_SET: &AsciiSet = &NON_ALPHANUMERIC
    .remove(b'-')
    .remove(b'.')
    .remove(b'_')
    .remove(b'~');

fn hex(c: u8) -> Option<u8> {
    match c {
        b'0'..=b'9' => Some(c - b'0'),
        b'a'..=b'f' => Some(c - b'a' + 10),
        b'A'..=b'F' => Some(c - b'A' + 10),
        _ => None,
    }
}

fn pct_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = String::with_capacity(s.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            if let (Some(hi), Some(lo)) = (hex(b[i + 1]), hex(b[i + 2])) {
                out.push((hi * 16 + lo) as char);
                i += 3;
                continue;
            }
        }
        out.push(b[i] as char);
        i += 1;
    }
    out
}

// Bend query parsing is RFC 3986 percent-decode only; '+' is not space.
fn parse_query(qs: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    for part in qs.split('&') {
        if part.is_empty() {
            continue;
        }
        let (k, v) = match part.split_once('=') {
            Some((k, v)) => (k, v),
            None => (part, ""),
        };
        out.push((pct_decode(k), pct_decode(v)));
    }
    out.sort_by(|a, b| a.0.cmp(&b.0));
    out
}

fn parse_origin(s: &str) -> Option<Sample> {
    if !s.starts_with('/') {
        return None;
    }
    let u = Url::parse(BASE).ok()?.join(s).ok()?;
    // url.path() keeps percent-encoding; Bend decodes the path (see url.bend parse.path).
    let path = pct_decode(u.path());
    // query_pairs treats '+' as space; Bend does not (RFC 3986 query).
    let q = parse_query(u.query().unwrap_or(""));
    Some(Sample { path, q })
}

fn enc_path(path: &str) -> String {
    utf8_percent_encode(path, PATH_SET).to_string()
}

fn enc_query(k: &str, v: &str) -> String {
    format!(
        "{}={}",
        utf8_percent_encode(k, QUERY_SET),
        utf8_percent_encode(v, QUERY_SET)
    )
}

fn encode_origin(path: &str, q: &[(String, String)]) -> String {
    let mut out = enc_path(path);
    if q.is_empty() {
        return out;
    }
    out.push('?');
    for (i, (k, v)) in q.iter().enumerate() {
        if i > 0 {
            out.push('&');
        }
        out.push_str(&enc_query(k, v));
    }
    out
}

fn score(u: Option<&Sample>) -> u32 {
    let Some(u) = u else { return 0 };
    let mut s = u.path.len() as u32;
    for (k, v) in &u.q {
        s += k.len() as u32 + v.len() as u32 + 1;
    }
    s
}

fn chk(s: &str) -> u32 {
    let mut h: u32 = 0;
    for c in s.bytes() {
        h = h.wrapping_mul(31).wrapping_add(c as u32);
    }
    h.wrapping_add(s.len() as u32)
}

fn parse_round() -> u32 {
    let mut acc = 0u32;
    for _ in 0..ROUNDS {
        for s in URLS {
            acc = acc.wrapping_add(score(parse_origin(s).as_ref()));
        }
    }
    acc
}

fn parsed_samples() -> Vec<Sample> {
    URLS.iter().filter_map(|s| parse_origin(s)).collect()
}

fn encode_round(samples: &[Sample]) -> u32 {
    let mut acc = 0u32;
    for _ in 0..ROUNDS {
        for u in samples {
            acc = acc.wrapping_add(chk(&encode_origin(&u.path, &u.q)));
        }
    }
    acc
}

fn main() {
    let t0 = Instant::now();
    let pchk = parse_round();
    println!("parse\t{:.3}\t{pchk}", t0.elapsed().as_secs_f64() * 1000.0);

    let samples = parsed_samples();
    let t0 = Instant::now();
    let echk = encode_round(&samples);
    println!("encode\t{:.3}\t{echk}", t0.elapsed().as_secs_f64() * 1000.0);
}
