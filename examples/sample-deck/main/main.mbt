// CLI binary — build the sample deck and emit its bytes as hex.
//
// Usage (from the project root):
//
//   mkdir -p out
//   moon run examples/sample-deck/main --target native | tail -1 | xxd -r -p > out/sample.pptx
//
// Then open `out/sample.pptx` in PowerPoint / Keynote / LibreOffice
// to inspect every typed feature in action.
//
// MoonBit's `core` only exposes `println(Show)` for I/O. To emit
// raw bytes without FFI (per the project policy in CLAUDE.md §8),
// we encode the deck bytes as a hex string and print it on a single
// line. The standard `xxd -r -p` decoder turns the hex back into
// the binary `.pptx` payload. `tail -1` strips any preceding
// `moon run` status lines.
//
// To bisect a PowerPoint Online compatibility issue, flip
// `split_mode` to `true` below: the CLI then emits one hex stream per entry
// (each preceded by `===FILE-NN-NAME===`), one for the title slide
// alone and one for the title plus each feature slide, so a shell
// fan-out can produce per-slide `.pptx` files for isolation testing.

///|
fn main {
  if split_mode {
    emit_split()
  } else {
    let bytes = build_sample_deck() catch {
      e => {
        println("build failed: \{e}")
        return
      }
    }
    println(bytes_to_hex(bytes))
  }
}

///|
/// Compile-time flag. Set to `true` to emit per-feature isolation
/// files (used for bisecting PowerPoint Online repair triggers);
/// `false` to emit the full deck. We use a compile-time
/// constant rather than argv because MoonBit's native CLI args vary
/// by backend, and the file is short enough that a re-build per
/// mode is acceptable.
let split_mode : Bool = false

///|
fn emit_split() -> Unit {
  let names = [
    "00-title-only", "01-text", "02-shapes", "03-custom-geom", "04-picture", "05-table",
    "06-charts-bar-line-pie", "07-charts-area-radar-doughnut", "08-charts-scatter-bubble",
    "09-charts-3d-stock-ofpie", "10-background", "11-combo-chart", "12-svg-image",
    "13-edit-shapes", "14-media", "15-master-template", "16-smartart", "17-animation",
    "18-online-video", "19-v06-features", "20-v07-features", "21-closing",
  ]
  for i in 0..<names.length() {
    let bytes = build_sample_isolated(i) catch {
      e => {
        println("build failed for feature " + i.to_string() + ": \{e}")
        continue
      }
    }
    println("===FILE-" + names[i] + "===")
    println(bytes_to_hex(bytes))
  }
  println("===END===")
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
