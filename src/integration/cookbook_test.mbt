// Cookbook example.
//
// Build a 5-slide pitch deck end-to-end using only the public
// `@presentation` + `@slide` API. The body of `build_pitch_deck`
// doubles as a worked example for docstrings / README quickstart.
//
// One inch = 914_400 EMU, one centimetre = 360_000 EMU. The default
// 4:3 slide is 9_144_000 × 6_858_000 EMU (10" × 7.5").

// --- inch-friendly EMU constants ---

///|
/// Default slide-coordinate space width (10 inches at 914_400 EMU/in).
let slide_w : Int64 = 9144000L

///|
/// Half-inch margin in EMU.
let margin : Int64 = 457200L

///|
/// Newtype wrap helper — keeps callers concise. We work with raw
/// `Int64` for arithmetic and only wrap at the API boundary.
fn emu(n : Int64) -> @units.Emu {
  @units.Emu(n)
}

// --- the deck ---

///|
/// Construct a 5-slide pitch deck and return the serialised bytes.
fn build_pitch_deck() -> FixedArray[Byte] raise {
  let prs = @presentation.Presentation::new()

  // Slide 1 — Title.
  let _ = prs.add_slide_mut(0)
  add_centered_textbox(
    prs,
    0,
    "MoonBit PPTX — a tiny pitch deck",
    id=2,
    y_offset=2438400L, // ~2.67" from top
  )

  // Slide 2 — Problem (body line above an emphasis box).
  let _ = prs.add_slide_mut(0)
  add_centered_textbox(
    prs,
    1,
    "Problem: OOXML is a 5000-page spec",
    id=2,
    y_offset=1219200L,
  )
  add_rect_at(
    prs,
    1,
    id=3,
    x=2286000L, // 2.5"
    y=3429000L, // 3.75"
    cx=4572000L, // 5"
    cy=1828800L, // 2"
  )

  // Slide 3 — Solution (body line + ellipse).
  let _ = prs.add_slide_mut(0)
  add_centered_textbox(
    prs,
    2,
    "Solution: types + writers do the lifting",
    id=2,
    y_offset=1219200L,
  )
  add_ellipse_centered(prs, 2, id=3, cx=2438400L, cy=1828800L)

  // Slide 4 — Demo (textbox + three labelled rectangles).
  let _ = prs.add_slide_mut(0)
  add_centered_textbox(
    prs,
    3,
    "Three lines of code → a slide",
    id=2,
    y_offset=914400L,
  )
  let rect_y = 3048000L
  let rect_h = 1219200L
  let rect_w = 2286000L
  let gap = 304800L
  let total = rect_w * 3L + gap * 2L
  let start_x = (slide_w - total) / 2L
  add_rect_at(prs, 3, id=3, x=start_x, y=rect_y, cx=rect_w, cy=rect_h)
  add_rect_at(
    prs,
    3,
    id=4,
    x=start_x + rect_w + gap,
    y=rect_y,
    cx=rect_w,
    cy=rect_h,
  )
  add_rect_at(
    prs,
    3,
    id=5,
    x=start_x + (rect_w + gap) * 2L,
    y=rect_y,
    cx=rect_w,
    cy=rect_h,
  )

  // Slide 5 — Closing.
  let _ = prs.add_slide_mut(0)
  add_centered_textbox(
    prs,
    4,
    "Thanks — try it on mooncakes.io",
    id=2,
    y_offset=3048000L,
  )
  prs.save()
}

///|
/// Helper: add a textbox spanning the slide width (minus margin) at
/// the given vertical offset. EMU arithmetic stays in `Int64` until
/// we wrap at the `AutoShape::textbox` boundary.
fn add_centered_textbox(
  prs : @presentation.Presentation,
  slide_idx : Int,
  text : String,
  id~ : Int,
  y_offset~ : Int64,
) -> Unit raise {
  let s = prs.slides()[slide_idx]
  let tb = @slide.AutoShape::textbox(
    id,
    "Title",
    emu(margin),
    emu(y_offset),
    emu(slide_w - margin * 2L),
    emu(914400L),
    text,
  )
  prs.update_slide_mut(slide_idx, s.with_shape(@slide.AutoShape(tb)))
}

///|
fn add_rect_at(
  prs : @presentation.Presentation,
  slide_idx : Int,
  id~ : Int,
  x~ : Int64,
  y~ : Int64,
  cx~ : Int64,
  cy~ : Int64,
) -> Unit raise {
  let s = prs.slides()[slide_idx]
  let r = @slide.AutoShape::rect(id, "Rect", emu(x), emu(y), emu(cx), emu(cy))
  prs.update_slide_mut(slide_idx, s.with_shape(@slide.AutoShape(r)))
}

///|
fn add_ellipse_centered(
  prs : @presentation.Presentation,
  slide_idx : Int,
  id~ : Int,
  cx~ : Int64,
  cy~ : Int64,
) -> Unit raise {
  let s = prs.slides()[slide_idx]
  let x = (slide_w - cx) / 2L
  let y = 3048000L
  let e = @slide.AutoShape::ellipse(
    id,
    "Ellipse",
    emu(x),
    emu(y),
    emu(cx),
    emu(cy),
  )
  prs.update_slide_mut(slide_idx, s.with_shape(@slide.AutoShape(e)))
}

// --- tests ---

///|
test "cookbook: pitch deck builds and round-trips" {
  let bytes = build_pitch_deck()
  let prs = @presentation.Presentation::open(bytes)
  let slides = prs.slides()
  assert_eq(slides.length(), 5)
  // Slides 1, 2, 3, 5 carry one body shape each (a textbox).
  assert_eq(slides[0].shapes.length(), 1)
  assert_eq(slides[1].shapes.length(), 2) // textbox + red rect
  assert_eq(slides[2].shapes.length(), 2) // textbox + ellipse
  assert_eq(slides[3].shapes.length(), 4) // textbox + 3 rects
  assert_eq(slides[4].shapes.length(), 1) // textbox
}

///|
test "cookbook: presentation.xml has 5 slide ID entries" {
  let bytes = build_pitch_deck()
  let prs = @presentation.Presentation::open(bytes)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_ids.length(), 5)
  // IDs start at 256 and increment.
  let mut i = 0
  while i < pres.sld_ids.length() {
    assert_eq(pres.sld_ids[i].id, 256L + i.to_int64())
    i = i + 1
  }
}

///|
test "cookbook: title slide carries the expected text" {
  let bytes = build_pitch_deck()
  let prs = @presentation.Presentation::open(bytes)
  let s = prs.slides()[0]
  match s.shapes[0] {
    AutoShape(a) =>
      assert_eq(
        a.text_body.unwrap().plain_text(),
        "MoonBit PPTX — a tiny pitch deck",
      )
    _ => fail("expected title textbox on slide 1")
  }
}

///|
test "cookbook: demo slide has the three labelled rectangles" {
  let bytes = build_pitch_deck()
  let prs = @presentation.Presentation::open(bytes)
  let s = prs.slides()[3]
  let mut rect_count = 0
  for sh in s.shapes {
    match sh {
      AutoShape(a) =>
        match a.geometry.unwrap() {
          Preset(p, _) =>
            if p == @slide.PresetShape::Rect && !(a.text_body is Some(_)) {
              rect_count = rect_count + 1
            }
          _ => ()
        }
      _ => ()
    }
  }
  assert_eq(rect_count, 3)
}
