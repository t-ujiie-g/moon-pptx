// Shared fixture helpers for slide parser tests.
//
// Every `*_test.mbt` in this package compiles into one blackbox-test
// package, so anything defined here is visible to every test file.
// Keeping the namespace literals and the UTF-8 encoder in one place
// removes the per-file duplication that crept in across Phase 3c/3d.

///|
/// Test-side aliases for the shared OOXML namespace URIs. Tests
/// interpolate these directly into XML string literals, so we expose them
/// under short names — the canonical definitions live in `@oxml`.
let pml_ns : String = @oxml.presentation_ns

///|
let dml_ns : String = @oxml.drawing_ns

///|
let off_rel_ns : String = @oxml.office_relationships_ns

///|
/// UTF-8 encode a string to a `FixedArray[Byte]`. Used by every test
/// fixture that hands raw bytes to `Slide::parse`. Handles every code
/// point, including the bullet glyph `•` (U+2022) and similar multi-byte
/// characters that appeared in earlier per-file copies.
fn fixture_bytes(s : String) -> FixedArray[Byte] {
  let buf : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp)
    } else if cp < 0x800 {
      buf.push(0xC0 | (cp >> 6))
      buf.push(0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      buf.push(0xE0 | (cp >> 12))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    } else {
      buf.push(0xF0 | (cp >> 18))
      buf.push(0x80 | ((cp >> 12) & 0x3F))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    }
  }
  let bytes = FixedArray::make(buf.length(), b'\x00')
  let mut i = 0
  while i < buf.length() {
    bytes[i] = buf[i].to_byte()
    i = i + 1
  }
  bytes
}
