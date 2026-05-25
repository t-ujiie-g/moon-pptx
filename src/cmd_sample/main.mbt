// CLI binary — build the sample deck and emit its bytes as hex.
//
// Usage (from the project root):
//
//   mkdir -p out
//   moon run src/cmd_sample --target native | tail -1 | xxd -r -p > out/sample.pptx
//
// Then open `out/sample.pptx` in PowerPoint / Keynote / LibreOffice
// to inspect every typed feature in action. The `out/` directory is
// in `.gitignore` so the generated artefact stays out of source
// control.
//
// MoonBit's `core` only exposes `println(Show)` for I/O. To emit
// raw bytes without FFI (per the project policy in CLAUDE.md §8),
// we encode the deck bytes as a hex string and print it on a single
// line. The standard `xxd -r -p` decoder turns the hex back into
// the binary `.pptx` payload. `tail -1` strips any preceding
// `moon run` status lines.

///|
fn main {
  let bytes = @sample.build_sample_deck() catch {
    e => {
      println("build failed: \{e}")
      return
    }
  }
  println(bytes_to_hex(bytes))
}

///|
/// Encode a byte sequence as a contiguous hex string. Two chars per
/// byte, lowercase, no spaces or separators — the canonical input
/// form for `xxd -r -p`.
fn bytes_to_hex(bytes : FixedArray[Byte]) -> String {
  let buf = StringBuilder::new()
  for b in bytes {
    let n = b.to_int()
    buf.write_char(hex_digit(n / 16))
    buf.write_char(hex_digit(n % 16))
  }
  buf.to_string()
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    (n + '0'.to_int()).unsafe_to_char()
  } else {
    (n - 10 + 'a'.to_int()).unsafe_to_char()
  }
}
