// moon-pptx side of the cross-library benchmark.
//
// Builds N slides with one text box each and serialises the package to
// bytes, matching `bench_pptx.py` and `bench_pptxgenjs.js`. Nothing is
// written to disk: the library has no file I/O (ADR-002), and the other
// two serialise to an in-memory buffer for the same reason — disk noise
// is not what the comparison is about.
//
// Prints the byte count so the work cannot be optimised away, and so a
// mismatched deck size is visible in the run log.
//
//   moon run main --target native -- <n>

///|
fn main {
  let args = @env.args()
  // args[0] is the program name.
  let n = if args.length() > 1 {
    @string.parse_int(args[1]) catch {
      _ => {
        println("usage: bench <slide-count>")
        return
      }
    }
  } else {
    100
  }
  let bytes = build_and_save(n) catch {
    e => {
      println("failed: " + e.to_string())
      return
    }
  }
  println(bytes.length().to_string())
}

///|
/// N slides, one text box each, serialised to bytes. `slides()` is lifted
/// out of the loop: calling it per slide re-parses every slide already in
/// the deck, which is quadratic (see ROADMAP.md §3.2).
fn build_and_save(n : Int) -> FixedArray[Byte] raise {
  let prs = @presentation.Presentation::new()
  for _ in 0..<n {
    let _ = prs.add_slide_mut(0)
  }
  let all = prs.slides()
  for i in 0..<n {
    let tb = @slide.AutoShape::textbox(
      id=2,
      name="Title",
      x=@units.Emu(457_200L),
      y=@units.Emu(457_200L),
      cx=@units.Emu(8_229_600L),
      cy=@units.Emu(914_400L),
      "Slide \{i + 1}",
    )
    prs.update_slide_mut(i, all[i].with_shape(@slide.AutoShape(tb)))
  }
  prs.save()
}
