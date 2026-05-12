// Shared signed-decimal integer parsers.
//
// OOXML attributes carry their numeric values as decimal strings with an
// optional leading sign (`-2700000`, `+50800`, `914400`). Every typed
// parser in `@oxml`, `@theme`, `@slide` needs to lift these strings into
// `Int` / `Int64`. Before this module existed there were six byte-for-byte
// identical copies of the same routine — one per error type — because each
// caller wanted to raise its own domain suberror on failure. The parser
// itself doesn't depend on the error type (it just returns `None`), so the
// duplication was pure friction; this file owns the single copy.

///|
/// Parse a signed decimal integer. Accepts an optional leading `+` / `-`.
/// Returns `None` if the input is empty, sign-only, or contains a
/// non-digit character.
pub fn parse_signed_int(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign = 1
  if chars[0] == '-' {
    sign = -1
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut acc = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(acc * sign)
}

///|
/// Like `parse_signed_int`, but for `Int64`. EMU attributes use this
/// because their range exceeds `Int` (e.g. slide widths of ~12 billion
/// EMU for a 13-inch slide overflow `Int` past ±2.1 billion).
pub fn parse_signed_int64(s : String) -> Int64? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign : Int64 = 1L
  if chars[0] == '-' {
    sign = -1L
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut acc : Int64 = 0L
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10L + (c.to_int() - '0'.to_int()).to_int64()
    i = i + 1
  }
  Some(acc * sign)
}
