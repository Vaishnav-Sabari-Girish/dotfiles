use std::io::{self, Cursor, Read};
use std::str::FromStr;
use std::{fmt, io::BufRead};

use chunked_transfer::Decoder as ChunkDecoder;
use log::debug;
use url::Url;

use crate::body::SizedReader;
use crate::error::{Error, ErrorKind::BadStatus};
use crate::header::{get_all_headers, get_header, Header, HeaderLine};
use crate::pool::PoolReturnRead;
use crate::stream::{DeadlineStream, ReadOnlyStream, Stream};
use crate::unit::Unit;
use crate::{stream, Agent, ErrorKind};

#[cfg(feature = "json")]
use serde::de::DeserializeOwned;

#[cfg(feature = "charset")]
use encoding_rs::Encoding;

#[cfg(feature = "gzip")]
use flate2::read::GzDecoder;

#[cfg(feature = "brotli")]
use brotli_decompressor::Decompressor as BrotliDecoder;

pub const DEFAULT_CONTENT_TYPE: &str = "text/plain";
pub const DEFAULT_CHARACTER_SET: &str = "utf-8";
const INTO_STRING_LIMIT: usize = 10 * 1_024 * 1_024;
// Follow the example of curl and limit a single header to 100kB:
// https://curl.se/libcurl/c/CURLOPT_HEADERFUNCTION.html
const MAX_HEADER_SIZE: usize = 100 * 1_024;
const MAX_HEADER_COUNT: usize = 100;

/// Response instances are created as results of firing off requests.
///
/// The `Response` is used to read response headers and decide what to do with the body.
/// Note that the socket connection is open and the body not read until one of
/// [`into_reader()`](#method.into_reader), [`into_json()`](#method.into_json), or
/// [`into_string()`](#method.into_string) consumes the response.
///
/// When dropping a `Response` instance, one one of two things can happen. If
/// the response has unread bytes, the underlying socket cannot be reused,
/// and the connection is closed. If there are no unread bytes, the connection
/// is returned to the [`Agent`](crate::Agent) connection pool used (notice there is always
/// an agent present, even when not explicitly configured by the user).
///
/// ```
/// # fn main() -> Result<(), ureq::Error> {
/// # ureq::is_test(true);
/// let response = ureq::get("http://example.com/").call()?;
///
/// // socket is still open and the response body has not been read.
///
/// let text = response.into_string()?;
///
/// // response is consumed, and body has been read.
/// # Ok(())
/// # }
/// ```
pub struct Response {
    pub(crate) url: Url,
    status_line: String,
    index: ResponseStatusIndex,
    status: u16,
    headers: Vec<Header>,
    // Boxed to avoid taking up too much size.
    unit: Box<Unit>,
    reader: Box<dyn Read + Send + Sync + 'static>,
    /// The redirect history of this response, if any. The history starts with
    /// the first response received and ends with the response immediately
    /// previous to this one.
    ///
    /// If this response was not redirected, the history is empty.
    pub(crate) history: Vec<Url>,
    /// The Content-Length value. The header itself may have been removed due to
    /// the automatic decompression system.
    length: Option<usize>,
    /// The compression type of the response body.
    compression: Option<Compression>,
}

/// index into status_line where we split: HTTP/1.1 200 OK
#[derive(Debug, Clone, Copy, Eq, PartialEq)]
struct ResponseStatusIndex {
    http_version: usize,
    response_code: usize,
}

impl fmt::Debug for Response {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "Response[status: {}, status_text: {}, url: {}]",
            self.status(),
            self.status_text(),
            self.url,
        )
    }
}

impl Response {
    /// Construct a response with a status, status text and a string body.
    ///
    /// This is hopefully useful for unit tests.
    ///
    /// Example:
    ///
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// # ureq::is_test(true);
    /// let resp = ureq::Response::new(401, "Authorization Required", "Please log in")?;
    ///
    /// assert_eq!(resp.status(), 401);
    /// # Ok(())
    /// # }
    /// ```
    pub fn new(status: u16, status_text: &str, body: &str) -> Result<Response, Error> {
        let r = format!("HTTP/1.1 {} {}\r\n\r\n{}", status, status_text, body);
        (r.as_ref() as &str).parse()
    }

    /// The URL we ended up at. This can differ from the request url when
    /// we have followed redirects.
    pub fn get_url(&self) -> &str {
        &self.url[..]
    }

    /// The http version: `HTTP/1.1`
    pub fn http_version(&self) -> &str {
        &self.status_line.as_str()[0..self.index.http_version]
    }

    /// The status as a u16: `200`
    pub fn status(&self) -> u16 {
        self.status
    }

    /// The status text: `OK`
    ///
    /// The HTTP spec allows for non-utf8 status texts. This uses from_utf8_lossy to
    /// convert such lines to &str.
    pub fn status_text(&self) -> &str {
        self.status_line.as_str()[self.index.response_code + 1..].trim()
    }

    /// The header value for the given name, or None if not found.
    ///
    /// For historical reasons, the HTTP spec allows for header values
    /// to be encoded using encodings like iso-8859-1. Such encodings
    /// means the values are not possible to interpret as utf-8.
    ///
    /// In case the header value can't be read as utf-8, this function
    /// returns `None` (while the name is visible in [`Response::headers_names()`]).
    pub fn header(&self, name: &str) -> Option<&str> {
        get_header(&self.headers, name)
    }

    /// A list of the header names in this response.
    /// Lowercased to be uniform.
    ///
    /// It's possible for a header name to be returned by this function, and
    /// still give a `None` value. See [`Response::header()`] for an explanation
    /// as to why.
    pub fn headers_names(&self) -> Vec<String> {
        self.headers
            .iter()
            .map(|h| h.name().to_lowercase())
            .collect()
    }

    /// Tells if the response has the named header.
    pub fn has(&self, name: &str) -> bool {
        self.header(name).is_some()
    }

    /// All headers corresponding values for the give name, or empty vector.
    pub fn all(&self, name: &str) -> Vec<&str> {
        get_all_headers(&self.headers, name)
    }

    /// The content type part of the "Content-Type" header without
    /// the charset.
    ///
    /// Example:
    ///
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// # ureq::is_test(true);
    /// let resp = ureq::get("http://example.com/").call()?;
    /// assert!(matches!(resp.header("content-type"), Some("text/html; charset=ISO-8859-1")));
    /// assert_eq!("text/html", resp.content_type());
    /// # Ok(())
    /// # }
    /// ```
    pub fn content_type(&self) -> &str {
        self.header("content-type")
            .map(|header| {
                header
                    .find(';')
                    .map(|index| &header[0..index])
                    .unwrap_or(header)
            })
            .unwrap_or(DEFAULT_CONTENT_TYPE)
    }

    /// The character set part of the "Content-Type".
    ///
    /// Example:
    ///
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// # ureq::is_test(true);
    /// let resp = ureq::get("http://example.com/").call()?;
    /// assert!(matches!(resp.header("content-type"), Some("text/html; charset=ISO-8859-1")));
    /// assert_eq!("ISO-8859-1", resp.charset());
    /// # Ok(())
    /// # }
    /// ```
    pub fn charset(&self) -> &str {
        charset_from_content_type(self.header("content-type"))
    }

    /// Turn this response into a `impl Read` of the body.
    ///
    /// 1. If `Transfer-Encoding: chunked`, the returned reader will unchunk it
    ///    and any `Content-Length` header is ignored.
    /// 2. If `Content-Length` is set, the returned reader is limited to this byte
    ///    length regardless of how many bytes the server sends.
    /// 3. If no length header, the reader is until server stream end.
    ///
    /// Note: If you use `read_to_end()` on the resulting reader, a malicious
    /// server might return enough bytes to exhaust available memory. If you're
    /// making requests to untrusted servers, you should use `.take()` to
    /// limit the response bytes read.
    ///
    /// Example:
    ///
    /// ```
    /// use std::io::Read;
    /// # fn main() -> Result<(), Box<dyn std::error::Error>> {
    /// # ureq::is_test(true);
    /// let resp = ureq::get("http://httpbin.org/bytes/100")
    ///     .call()?;
    ///
    /// assert!(resp.has("Content-Length"));
    /// let len: usize = resp.header("Content-Length")
    ///     .unwrap()
    ///     .parse()?;
    ///
    /// let mut bytes: Vec<u8> = Vec::with_capacity(len);
    /// resp.into_reader()
    ///     .take(10_000_000)
    ///     .read_to_end(&mut bytes)?;
    ///
    /// assert_eq!(bytes.len(), len);
    /// # Ok(())
    /// # }
    /// ```
    pub fn into_reader(self) -> Box<dyn Read + Send + Sync + 'static> {
        self.reader
    }

    fn stream_to_reader(&self, stream: DeadlineStream) -> Box<dyn Read + Send + Sync + 'static> {
        //
        let is_http10 = self.http_version().eq_ignore_ascii_case("HTTP/1.0");
        let is_close = self
            .header("connection")
            .map(|c| c.eq_ignore_ascii_case("close"))
            .unwrap_or(false);

        let is_head = self.unit.is_head();
        let has_no_body = is_head
            || match self.status {
                204 | 304 => true,
                _ => false,
            };

        let is_chunked = self
            .header("transfer-encoding")
            .map(|enc| !enc.is_empty()) // whatever it says, do chunked
            .unwrap_or(false);

        let use_chunked = !is_http10 && !has_no_body && is_chunked;

        let limit_bytes = if is_http10 || is_close {
            None
        } else if has_no_body {
            // head requests never have a body
            Some(0)
        } else {
            self.length
        };

        let unit = &self.unit;
        let inner = stream.inner_ref();
        let result = inner.set_read_timeout(unit.agent.config.timeout_read);
        if let Err(e) = result {
            return Box::new(ErrorReader(e)) as Box<dyn Read + Send + Sync + 'static>;
        }
        let buffer_len = inner.buffer().len();

        let body_reader: Box<dyn Read + Send + Sync> = match (use_chunked, limit_bytes) {
            // Chunked responses have an unknown length, but do have an end of body
            // marker. When we encounter the marker, we can return the underlying stream
            // to the connection pool.
            (true, _) => {
                debug!("Chunked body in response");
                Box::new(PoolReturnRead::new(
                    &unit.agent,
                    &unit.url,
                    ChunkDecoder::new(stream),
                ))
            }
            // Responses with a content-length header means we should limit the reading
            // of the body to the number of bytes in the header. Once done, we can
            // return the underlying stream to the connection pool.
            (false, Some(len)) => {
                let mut pooler =
                    PoolReturnRead::new(&unit.agent, &unit.url, LimitedRead::new(stream, len));

                if len <= buffer_len {
                    debug!("Body entirely buffered (length: {})", len);
                    let mut buf = vec![0; len];
                    pooler
                        .read_exact(&mut buf)
                        .expect("failed to read exact buffer length from stream");
                    Box::new(Cursor::new(buf))
                } else {
                    debug!("Streaming body until content-length: {}", len);
                    Box::new(pooler)
                }
            }
            (false, None) => {
                debug!("Body of unknown size - read until socket close");
                Box::new(stream)
            }
        };

        match self.compression {
            None => body_reader,
            Some(c) => c.wrap_reader(body_reader),
        }
    }

    /// Turn this response into a String of the response body. By default uses `utf-8`,
    /// but can work with charset, see below.
    ///
    /// This is potentially memory inefficient for large bodies since the
    /// implementation first reads the reader to end into a `Vec<u8>` and then
    /// attempts to decode it using the charset.
    ///
    /// If the response is larger than 10 megabytes, this will return an error.
    ///
    /// Example:
    ///
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// # ureq::is_test(true);
    /// let text = ureq::get("http://httpbin.org/get/success")
    ///     .call()?
    ///     .into_string()?;
    ///
    /// assert!(text.contains("success"));
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// ## Charset support
    ///
    /// If you enable feature `ureq = { version = "*", features = ["charset"] }`, into_string()
    /// attempts to respect the character encoding of the `Content-Type` header. If there is no
    /// Content-Type header, or the Content-Type header does not specify a charset, into_string()
    /// uses `utf-8`.
    ///
    /// I.e. `Content-Length: text/plain; charset=iso-8859-1` would be decoded in latin-1.
    ///
    pub fn into_string(self) -> io::Result<String> {
        #[cfg(feature = "charset")]
        let encoding = Encoding::for_label(self.charset().as_bytes())
            .or_else(|| Encoding::for_label(DEFAULT_CHARACTER_SET.as_bytes()))
            .unwrap();

        let mut buf: Vec<u8> = vec![];
        self.into_reader()
            .take((INTO_STRING_LIMIT + 1) as u64)
            .read_to_end(&mut buf)?;
        if buf.len() > INTO_STRING_LIMIT {
            return Err(io::Error::new(
                io::ErrorKind::Other,
                "response too big for into_string",
            ));
        }

        #[cfg(feature = "charset")]
        {
            let (text, _, _) = encoding.decode(&buf);
            Ok(text.into_owned())
        }
        #[cfg(not(feature = "charset"))]
        {
            Ok(String::from_utf8_lossy(&buf).to_string())
        }
    }

    /// Read the body of this response into a serde_json::Value, or any other type that
    /// implements the [serde::Deserialize] trait.
    ///
    /// You must use either a type annotation as shown below (`message: Message`), or the
    /// [turbofish operator] (`::<Type>`) so Rust knows what type you are trying to read.
    ///
    /// [turbofish operator]: https://matematikaadit.github.io/posts/rust-turbofish.html
    ///
    /// Requires feature `ureq = { version = "*", features = ["json"] }`
    ///
    /// Example:
    ///
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// # ureq::is_test(true);
    /// // This import requires the `derive` feature on `serde`.
    /// // Put this in Cargo.toml: serde = { version = "1", features = ["derive"] }
    /// use serde::{Deserialize};
    ///
    /// // An alternative way to is to use the `serde_derive` crate.
    /// // Put this in Cargo.toml: serde_derive = "1"
    /// // use serde_derive::{Deserialize};
    ///
    /// #[derive(Deserialize)]
    /// struct Message {
    ///     hello: String,
    /// }
    ///
    /// let message: Message =
    ///     ureq::get("http://example.com/hello_world.json")
    ///         .call()?
    ///         .into_json()?;
    ///
    /// assert_eq!(message.hello, "world");
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// Or, if you don't want to define a struct to read your JSON into, you can
    /// use the convenient `serde_json::Value` type to parse arbitrary or unknown
    /// JSON.
    ///
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// # ureq::is_test(true);
    /// let json: serde_json::Value = ureq::get("http://example.com/hello_world.json")
    ///     .call()?
    ///     .into_json()?;
    ///
    /// assert_eq!(json["hello"], "world");
    /// # Ok(())
    /// # }
    /// ```
    #[cfg(feature = "json")]
    pub fn into_json<T: DeserializeOwned>(self) -> io::Result<T> {
        use crate::stream::io_err_timeout;
        use std::error::Error;

        let reader = self.into_reader();
        serde_json::from_reader(reader).map_err(|e| {
            // This is to unify TimedOut io::Error in the API.
            // We make a clone of the original error since serde_json::Error doesn't
            // let us get the wrapped error instance back.
            if let Some(ioe) = e.source().and_then(|s| s.downcast_ref::<io::Error>()) {
                if ioe.kind() == io::ErrorKind::TimedOut {
                    return io_err_timeout(ioe.to_string());
                }
            }

            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("Failed to read JSON: {}", e),
            )
        })
    }

    /// Create a response from a Read trait impl.
    ///
    /// This is hopefully useful for unit tests.
    ///
    /// Example:
    ///
    /// use std::io::Cursor;
    ///
    /// let text = "HTTP/1.1 401 Authorization Required\r\n\r\nPlease log in\n";
    /// let read = Cursor::new(text.to_string().into_bytes());
    /// let resp = ureq::Response::do_from_read(read);
    ///
    /// assert_eq!(resp.status(), 401);
    pub(crate) fn do_from_stream(stream: Stream, unit: Unit) -> Result<Response, Error> {
        //
        // HTTP/1.1 200 OK\r\n
        let mut stream = stream::DeadlineStream::new(stream, unit.deadline);

        // The status line we can ignore non-utf8 chars and parse as_str_lossy().
        let status_line = read_next_line(&mut stream, "the status line")?.into_string_lossy();
        let (index, status) = parse_status_line(status_line.as_str())?;

        let mut headers: Vec<Header> = Vec::new();
        while headers.len() <= MAX_HEADER_COUNT {
            let line = read_next_line(&mut stream, "a header")?;
            if line.is_empty() {
                break;
            }
            if let Ok(header) = line.into_header() {
                headers.push(header);
            }
        }

        if headers.len() > MAX_HEADER_COUNT {
            return Err(ErrorKind::BadHeader.msg(
                format!("more than {} header fields in response", MAX_HEADER_COUNT).as_str(),
            ));
        }

        let length = get_header(&headers, "content-length").and_then(|v| v.parse::<usize>().ok());

        let compression =
            get_header(&headers, "content-encoding").and_then(Compression::from_header_value);

        // remove Content-Encoding and length due to automatic decompression
        if compression.is_some() {
            headers.retain(|h| !h.is_name("content-encoding") && !h.is_name("content-length"));
        }

        let url = unit.url.clone();

        let mut response = Response {
            url,
            status_line,
            index,
            status,
            headers,
            unit: Box::new(unit),
            reader: Box::new(Cursor::new(vec![])),
            history: vec![],
            length,
            compression,
        };
        response.reader = response.stream_to_reader(stream);
        Ok(response)
    }

    #[cfg(test)]
    pub fn set_url(&mut self, url: Url) {
        self.url = url;
    }

    #[cfg(test)]
    pub fn history_from_previous(&mut self, previous: Response) {
        self.history = previous.history;
        self.history.push(previous.url);
    }
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
enum Compression {
    #[cfg(feature = "brotli")]
    Brotli,
    #[cfg(feature = "gzip")]
    Gzip,
}

impl Compression {
    /// Convert a string like "br" to an enum value
    fn from_header_value(value: &str) -> Option<Compression> {
        match value {
            #[cfg(feature = "brotli")]
            "br" => Some(Compression::Brotli),
            #[cfg(feature = "gzip")]
            "gzip" | "x-gzip" => Some(Compression::Gzip),
            _ => None,
        }
    }

    /// Wrap the raw reader with a decompressing reader
    #[allow(unused_variables)] // when no features enabled, reader is unused (unreachable)
    fn wrap_reader(
        self,
        reader: Box<dyn Read + Send + Sync + 'static>,
    ) -> Box<dyn Read + Send + Sync + 'static> {
        match self {
            #[cfg(feature = "brotli")]
            Compression::Brotli => Box::new(BrotliDecoder::new(reader, 4096)),
            #[cfg(feature = "gzip")]
            Compression::Gzip => Box::new(GzDecoder::new(reader)),
        }
    }
}

/// parse a line like: HTTP/1.1 200 OK\r\n
fn parse_status_line(line: &str) -> Result<(ResponseStatusIndex, u16), Error> {
    //

    if !line.is_ascii() {
        return Err(BadStatus.msg("Status line not ASCII"));
    }
    // https://tools.ietf.org/html/rfc7230#section-3.1.2
    //      status-line = HTTP-version SP status-code SP reason-phrase CRLF
    let mut split: Vec<&str> = line.splitn(3, ' ').collect();
    if split.len() == 2 {
        // As a special case, we are lenient parsing lines without a space after the code.
        // This is technically against spec. "HTTP/1.1 200\r\n"
        split.push("");
    }
    if split.len() != 3 {
        return Err(BadStatus.msg("Wrong number of tokens in status line"));
    }

    // https://tools.ietf.org/html/rfc7230#appendix-B
    //    HTTP-name = %x48.54.54.50 ; HTTP
    //    HTTP-version = HTTP-name "/" DIGIT "." DIGIT
    let http_version = split[0];
    if !http_version.starts_with("HTTP/") {
        return Err(BadStatus.msg("HTTP version did not start with HTTP/"));
    }
    if http_version.len() != 8 {
        return Err(BadStatus.msg("HTTP version was wrong length"));
    }
    if !http_version.as_bytes()[5].is_ascii_digit() || !http_version.as_bytes()[7].is_ascii_digit()
    {
        return Err(BadStatus.msg("HTTP version did not match format"));
    }

    let status_str: &str = split[1];
    //      status-code    = 3DIGIT
    if status_str.len() != 3 {
        return Err(BadStatus.msg("Status code was wrong length"));
    }

    let status: u16 = status_str
        .parse()
        .map_err(|_| BadStatus.msg(format!("unable to parse status as u16 ({})", status_str)))?;

    Ok((
        ResponseStatusIndex {
            http_version: http_version.len(),
            response_code: http_version.len() + status_str.len(),
        },
        status,
    ))
}

impl FromStr for Response {
    type Err = Error;
    /// Parse a response from a string.
    ///
    /// Example:
    /// ```
    /// # fn main() -> Result<(), ureq::Error> {
    /// let s = "HTTP/1.1 200 OK\r\n\
    ///     X-Forwarded-For: 1.2.3.4\r\n\
    ///     Content-Type: text/plain\r\n\
    ///     \r\n\
    ///     Hello World!!!";
    /// let resp: ureq::Response = s.parse()?;
    /// assert!(resp.has("X-Forwarded-For"));
    /// let body = resp.into_string()?;
    /// assert_eq!(body, "Hello World!!!");
    /// # Ok(())
    /// # }
    /// ```
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let stream = Stream::new(ReadOnlyStream::new(s.into()));
        let request_url = "https://example.com".parse().unwrap();
        let request_reader = SizedReader {
            size: crate::body::BodySize::Empty,
            reader: Box::new(std::io::empty()),
        };
        let unit = Unit::new(
            &Agent::new(),
            "GET",
            &request_url,
            vec![],
            &request_reader,
            None,
        );
        Self::do_from_stream(stream, unit)
    }
}

fn read_next_line(reader: &mut impl BufRead, context: &str) -> io::Result<HeaderLine> {
    let mut buf = Vec::new();
    let result = reader
        .take((MAX_HEADER_SIZE + 1) as u64)
        .read_until(b'\n', &mut buf);

    match result {
        Ok(0) => Err(io::Error::new(
            io::ErrorKind::ConnectionAborted,
            "Unexpected EOF",
        )),
        Ok(n) if n > MAX_HEADER_SIZE => Err(io::Error::new(
            io::ErrorKind::Other,
            format!("header field longer than {} bytes", MAX_HEADER_SIZE),
        )),
        Ok(_) => Ok(()),
        Err(e) => {
            // Provide context to errors encountered while reading the line.
            let reason = format!("Error encountered in {}", context);

            let kind = e.kind();

            // Use an intermediate wrapper type which carries the error message
            // as well as a .source() reference to the original error.
            let wrapper = Error::new(ErrorKind::Io, Some(reason)).src(e);

            Err(io::Error::new(kind, wrapper))
        }
    }?;

    if !buf.ends_with(b"\n") {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("Header field didn't end with \\n: {:?}", buf),
        ));
    }

    buf.pop();
    if buf.ends_with(b"\r") {
        buf.pop();
    }

    Ok(buf.into())
}

/// Limits a `Read` to a content size (as set by a "Content-Length" header).
pub(crate) struct LimitedRead<R> {
    reader: R,
    limit: usize,
    position: usize,
}

impl<R: Read> LimitedRead<R> {
    pub(crate) fn new(reader: R, limit: usize) -> Self {
        LimitedRead {
            reader,
            limit,
            position: 0,
        }
    }

    pub(crate) fn remaining(&self) -> usize {
        self.limit - self.position
    }
}

impl<R: Read> Read for LimitedRead<R> {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        if self.remaining() == 0 {
            return Ok(0);
        }
        let from = if self.remaining() < buf.len() {
            &mut buf[0..self.remaining()]
        } else {
            buf
        };
        match self.reader.read(from) {
            // https://tools.ietf.org/html/rfc7230#page-33
            // If the sender closes the connection or
            // the recipient times out before the indicated number of octets are
            // received, the recipient MUST consider the message to be
            // incomplete and close the connection.
            Ok(0) => Err(io::Error::new(
                io::ErrorKind::UnexpectedEof,
                "response body closed before all bytes were read",
            )),
            Ok(amount) => {
                self.position += amount;
                Ok(amount)
            }
            Err(e) => Err(e),
        }
    }
}

impl<R: Read> From<LimitedRead<R>> for Stream
where
    Stream: From<R>,
{
    fn from(limited_read: LimitedRead<R>) -> Stream {
        limited_read.reader.into()
    }
}

/// Extract the charset from a "Content-Type" header.
///
/// "Content-Type: text/plain; charset=iso8859-1" -> "iso8859-1"
///
/// *Internal API*
pub(crate) fn charset_from_content_type(header: Option<&str>) -> &str {
    header
        .and_then(|header| {
            header.find(';').and_then(|semi| {
                (&header[semi + 1..])
                    .find('=')
                    .map(|equal| (&header[semi + equal + 2..]).trim())
            })
        })
        .unwrap_or(DEFAULT_CHARACTER_SET)
}

// ErrorReader returns an error for every read.
// The error is as close to a clone of the underlying
// io::Error as we can get.
struct ErrorReader(io::Error);

impl Read for ErrorReader {
    fn read(&mut self, _buf: &mut [u8]) -> io::Result<usize> {
        Err(io::Error::new(self.0.kind(), self.0.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use super::*;

    #[test]
    fn short_read() {
        use std::io::Cursor;
        let mut lr = LimitedRead::new(Cursor::new(vec![b'a'; 3]), 10);
        let mut buf = vec![0; 1000];
        let result = lr.read_to_end(&mut buf);
        assert!(result.err().unwrap().kind() == io::ErrorKind::UnexpectedEof);
    }

    #[test]
    fn content_type_without_charset() {
        let s = "HTTP/1.1 200 OK\r\n\
                 Content-Type: application/json\r\n\
                 \r\n\
                 OK";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("application/json", resp.content_type());
    }

    #[test]
    fn content_type_without_cr() {
        let s = "HTTP/1.1 200 OK\r\n\
                 Content-Type: application/json\n\
                 \r\n\
                 OK";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("application/json", resp.content_type());
    }

    #[test]
    fn content_type_with_charset() {
        let s = "HTTP/1.1 200 OK\r\n\
                 Content-Type: application/json; charset=iso-8859-4\r\n\
                 \r\n\
                 OK";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("application/json", resp.content_type());
    }

    #[test]
    fn content_type_default() {
        let s = "HTTP/1.1 200 OK\r\n\r\nOK";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("text/plain", resp.content_type());
    }

    #[test]
    fn charset() {
        let s = "HTTP/1.1 200 OK\r\n\
                 Content-Type: application/json; charset=iso-8859-4\r\n\
                 \r\n\
                 OK";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("iso-8859-4", resp.charset());
    }

    #[test]
    fn charset_default() {
        let s = "HTTP/1.1 200 OK\r\n\
                 Content-Type: application/json\r\n\
                 \r\n\
                 OK";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("utf-8", resp.charset());
    }

    #[test]
    fn chunked_transfer() {
        let s = "HTTP/1.1 200 OK\r\n\
                 Transfer-Encoding: Chunked\r\n\
                 \r\n\
                 3\r\n\
                 hel\r\n\
                 b\r\n\
                 lo world!!!\r\n\
                 0\r\n\
                 \r\n";
        let resp = s.parse::<Response>().unwrap();
        assert_eq!("hello world!!!", resp.into_string().unwrap());
    }

    #[test]
    fn into_string_large() {
        const LEN: usize = INTO_STRING_LIMIT + 1;
        let s = format!(
            "HTTP/1.1 200 OK\r\n\
                 Content-Length: {}\r\n
                 \r\n
                 {}",
            LEN,
            "A".repeat(LEN),
        );
        let result = s.parse::<Response>().unwrap();
        let err = result
            .into_string()
            .expect_err("didn't error with too-long body");
        assert_eq!(err.to_string(), "response too big for into_string");
        assert_eq!(err.kind(), io::ErrorKind::Other);
    }

    #[test]
    #[cfg(feature = "json")]
    fn parse_simple_json() {
        let s = "HTTP/1.1 200 OK\r\n\
             \r\n\
             {\"hello\":\"world\"}";
        let resp = s.parse::<Response>().unwrap();
        let v: serde_json::Value = resp.into_json().unwrap();
        let compare = "{\"hello\":\"world\"}"
            .parse::<serde_json::Value>()
            .unwrap();
        assert_eq!(v, compare);
    }

    #[test]
    #[cfg(feature = "json")]
    fn parse_deserialize_json() {
        use serde::Deserialize;

        #[derive(Deserialize)]
        struct Hello {
            hello: String,
        }

        let s = "HTTP/1.1 200 OK\r\n\
             \r\n\
             {\"hello\":\"world\"}";
        let resp = s.parse::<Response>().unwrap();
        let v: Hello = resp.into_json::<Hello>().unwrap();
        assert_eq!(v.hello, "world");
    }

    #[test]
    fn parse_borked_header() {
        let s = "HTTP/1.1 BORKED\r\n".to_string();
        let err = s.parse::<Response>().unwrap_err();
        assert_eq!(err.kind(), BadStatus);
    }

    #[test]
    fn parse_header_without_reason() {
        let s = "HTTP/1.1 302\r\n\r\n".to_string();
        let resp = s.parse::<Response>().unwrap();
        assert_eq!(resp.status_text(), "");
    }

    #[test]
    fn read_next_line_large() {
        const LEN: usize = MAX_HEADER_SIZE + 1;
        let s = format!("Long-Header: {}\r\n", "A".repeat(LEN),);
        let mut cursor = Cursor::new(s);
        let result = read_next_line(&mut cursor, "some context");
        let err = result.expect_err("did not error on too-large header");
        assert_eq!(err.kind(), io::ErrorKind::Other);
        assert_eq!(
            err.to_string(),
            format!("header field longer than {} bytes", MAX_HEADER_SIZE)
        );
    }

    #[test]
    fn too_many_headers() {
        const LEN: usize = MAX_HEADER_COUNT + 1;
        let s = format!(
            "HTTP/1.1 200 OK\r\n\
                 {}
                 \r\n
                 hi",
            "Header: value\r\n".repeat(LEN),
        );
        let err = s
            .parse::<Response>()
            .expect_err("did not error on too many headers");
        assert_eq!(err.kind(), ErrorKind::BadHeader);
        assert_eq!(
            err.to_string(),
            format!(
                "Bad Header: more than {} header fields in response",
                MAX_HEADER_COUNT
            )
        );
    }

    #[test]
    #[cfg(feature = "charset")]
    fn read_next_line_non_ascii_reason() {
        let (cow, _, _) =
            encoding_rs::WINDOWS_1252.encode("HTTP/1.1 302 Déplacé Temporairement\r\n");
        let bytes = cow.to_vec();
        let mut reader = io::BufReader::new(io::Cursor::new(bytes));
        let r = read_next_line(&mut reader, "test status line");
        let h = r.unwrap();
        assert_eq!(h.to_string(), "HTTP/1.1 302 D�plac� Temporairement");
    }

    #[test]
    #[cfg(feature = "charset")]
    fn parse_header_with_non_utf8() {
        let (cow, _, _) = encoding_rs::WINDOWS_1252.encode(
            "HTTP/1.1 200 OK\r\n\
            x-geo-header: gött mos!\r\n\
            \r\n\
            OK",
        );
        let v = cow.to_vec();
        let s = Stream::new(ReadOnlyStream::new(v));
        let request_url = "https://example.com".parse().unwrap();
        let request_reader = SizedReader {
            size: crate::body::BodySize::Empty,
            reader: Box::new(std::io::empty()),
        };
        let unit = Unit::new(
            &Agent::new(),
            "GET",
            &request_url,
            vec![],
            &request_reader,
            None,
        );
        let resp = Response::do_from_stream(s.into(), unit).unwrap();
        assert_eq!(resp.status(), 200);
        assert_eq!(resp.header("x-geo-header"), None);
    }

    #[test]
    fn history() {
        let mut response0 = Response::new(302, "Found", "").unwrap();
        response0.set_url("http://1.example.com/".parse().unwrap());
        assert!(response0.history.is_empty());

        let mut response1 = Response::new(302, "Found", "").unwrap();
        response1.set_url("http://2.example.com/".parse().unwrap());
        response1.history_from_previous(response0);

        let mut response2 = Response::new(404, "NotFound", "").unwrap();
        response2.set_url("http://2.example.com/".parse().unwrap());
        response2.history_from_previous(response1);

        let hist: Vec<String> = response2.history.iter().map(|r| r.to_string()).collect();
        assert_eq!(hist, ["http://1.example.com/", "http://2.example.com/"])
    }

    #[test]
    fn response_implements_send_and_sync() {
        let _response: Box<dyn Send> = Box::new(Response::new(302, "Found", "").unwrap());
        let _response: Box<dyn Sync> = Box::new(Response::new(302, "Found", "").unwrap());
    }

    #[test]
    fn ensure_response_size() {
        // This is platform dependent, so we can't be too strict or precise.
        let size = std::mem::size_of::<Response>();
        println!("Response size: {}", size);
        assert!(size < 400); // 200 on Macbook M1
    }
}
