// Slide reordering tests (roadmap v0.3.1 E2).

///|
/// Stamp a slide with a one-textbox marker so reorder/duplicate tests
/// can tell slides apart (blank slides are otherwise identical).
fn stamp_slide(
  prs : @presentation.Presentation,
  idx : Int,
  marker : String,
) -> Unit raise {
  let tb = @slide.AutoShape::textbox(
    2,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
    marker,
  )
  prs.update_slide_mut(idx, prs.slides()[idx].with_shape(@slide.AutoShape(tb)))
}

///|
/// Read back the marker text of a slide's first shape.
fn marker_of(s : @slide.Slide) -> String {
  match s.shapes[0] {
    AutoShape(a) => a.text_body.unwrap().plain_text()
    _ => "?"
  }
}

///|
test "move_slide_mut: sends the first slide to the end" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "S0")
  stamp_slide(prs, 1, "S1")
  stamp_slide(prs, 2, "S2")
  prs.move_slide_mut(0, 2)
  let slides = prs.slides()
  assert_eq(marker_of(slides[0]), "S1")
  assert_eq(marker_of(slides[1]), "S2")
  assert_eq(marker_of(slides[2]), "S0")
}

///|
test "move_slide_mut: moves a later slide forward" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "S0")
  stamp_slide(prs, 1, "S1")
  stamp_slide(prs, 2, "S2")
  prs.move_slide_mut(2, 0)
  let slides = prs.slides()
  assert_eq(marker_of(slides[0]), "S2")
  assert_eq(marker_of(slides[1]), "S0")
  assert_eq(marker_of(slides[2]), "S1")
}

///|
test "move_slide_mut: from == to is a no-op" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "S0")
  stamp_slide(prs, 1, "S1")
  prs.move_slide_mut(1, 1)
  let slides = prs.slides()
  assert_eq(marker_of(slides[0]), "S0")
  assert_eq(marker_of(slides[1]), "S1")
}

///|
test "move_slide_mut: order survives save → reopen, no part renaming" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "first")
  stamp_slide(prs, 1, "second")
  prs.move_slide_mut(0, 1)
  let reopened = @presentation.Presentation::open(prs.save())
  let slides = reopened.slides()
  assert_eq(marker_of(slides[0]), "second")
  assert_eq(marker_of(slides[1]), "first")
  // Reordering is pure sldIdLst — the parts keep their names.
  assert_true(reopened.pkg.part_by_name("/ppt/slides/slide1.xml") is Some(_))
  assert_true(reopened.pkg.part_by_name("/ppt/slides/slide2.xml") is Some(_))
}

///|
test "move_slide_mut: out-of-range index raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  try prs.move_slide_mut(0, 9) catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
  try prs.move_slide_mut(-1, 0) catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "with_slide_moved: immutable — original order preserved" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "A")
  stamp_slide(prs, 1, "B")
  let moved = prs.with_slide_moved(0, 1)
  assert_eq(marker_of(prs.slides()[0]), "A")
  assert_eq(marker_of(moved.slides()[0]), "B")
}
