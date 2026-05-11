// Shared UTF-8 decoding helper.
//
// Every OOXML content-XML parser (theme, slide_master, slide, …) receives
// part bytes from the OPC layer and needs to feed a `String` to
// `@xml.XmlReader`. Rather than each package re-implementing the same
// 40-line UTF-8 decoder, we own a single source of truth here.
//
// The function is `pub` and raises a `Utf8Error` suberror at the boundary;
// each domain parser wraps `Utf8Error` into its own `*Error` variant via
// a tiny `try ... catch` so the public API surface stays domain-typed.

///|
/// Errors raised by `bytes_to_string`. Each variant captures the byte
/// offset where decoding failed, so callers can surface a precise
/// position when reporting "malformed part bytes".
pub(all) suberror Utf8Error {
  StrayContinuation(Int)
  TruncatedSequence(Int)
} derive(Eq, Debug)

///|
pub impl Show for Utf8Error with output(self, logger) {
  match self {
    StrayContinuation(off) => {
      logger.write_string("StrayContinuation(offset=")
      logger.write_object(off)
      logger.write_string(")")
    }
    TruncatedSequence(off) => {
      logger.write_string("TruncatedSequence(offset=")
      logger.write_object(off)
      logger.write_string(")")
    }
  }
}

///|
/// Decode UTF-8 bytes to a `String`. Accepts the full BMP and supplementary
/// planes (1- to 4-byte sequences).
///
/// Raises `Utf8Error` on stray continuation bytes or truncated sequences.
/// Does NOT validate overlong encodings or surrogate code points — readers
/// further up the stack expect to receive whatever bytes the underlying
/// OPC package gave us; tighter validation is a future hardening pass.
pub fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise Utf8Error {
  let chars : Array[Char] = []
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int().land(0xFF)
    if b0 < 0x80 {
      chars.push(b0.unsafe_to_char())
      i = i + 1
    } else if b0 < 0xC0 {
      raise StrayContinuation(i)
    } else if b0 < 0xE0 {
      if i + 1 >= bytes.length() {
        raise TruncatedSequence(i)
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let cp = (b0 - 0xC0) * 0x40 + (b1 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= bytes.length() {
        raise TruncatedSequence(i)
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let b2 = bytes[i + 2].to_int().land(0xFF)
      let cp = (b0 - 0xE0) * 0x1000 + (b1 - 0x80) * 0x40 + (b2 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 3
    } else {
      if i + 3 >= bytes.length() {
        raise TruncatedSequence(i)
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let b2 = bytes[i + 2].to_int().land(0xFF)
      let b3 = bytes[i + 3].to_int().land(0xFF)
      let cp = (b0 - 0xF0) * 0x40000 +
        (b1 - 0x80) * 0x1000 +
        (b2 - 0x80) * 0x40 +
        (b3 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 4
    }
  }
  String::from_array(chars)
}
