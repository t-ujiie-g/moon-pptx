// Immutable builder tests.

///|
test "with_added_slide: original presentation untouched" {
  let prs0 = @presentation.Presentation::new()
  let (prs1, name) = prs0.with_added_slide(layout_index=0)
  assert_eq(name, "/ppt/slides/slide1.xml")
  // Original has no slides; new value has one.
  assert_eq(prs0.slides().length(), 0)
  assert_eq(prs1.slides().length(), 1)
}

///|
test "with_added_slide: chained calls accumulate independently" {
  let prs0 = @presentation.Presentation::new()
  let (prs1, _) = prs0.with_added_slide(layout_index=0)
  let (prs2, _) = prs1.with_added_slide(layout_index=0)
  assert_eq(prs0.slides().length(), 0)
  assert_eq(prs1.slides().length(), 1)
  assert_eq(prs2.slides().length(), 2)
}

///|
test "with_slide_updated: original presentation's slide untouched" {
  let prs0 = @presentation.Presentation::new()
  let (prs1, _) = prs0.with_added_slide(layout_index=0)
  // The added slide is empty.
  assert_eq(prs1.slides()[0].shapes.length(), 0)
  let tb = @slide.AutoShape::textbox(
    2,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
    "Hi",
  )
  let s = prs1.slides()[0]
  let prs2 = prs1.with_slide_updated(0, s.with_shape(@slide.AutoShape(tb)))
  // prs1's slide is still empty; prs2's has the textbox.
  assert_eq(prs1.slides()[0].shapes.length(), 0)
  assert_eq(prs2.slides()[0].shapes.length(), 1)
}

///|
test "with_added_slide + with_slide_updated: save + reopen round-trips" {
  let prs = @presentation.Presentation::new()
  let (prs, _) = prs.with_added_slide(layout_index=0)
  let s = prs.slides()[0]
  let tb = @slide.AutoShape::textbox(
    2,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914400L),
    @units.Emu(457200L),
    "Immutable!",
  )
  let prs = prs.with_slide_updated(0, s.with_shape(@slide.AutoShape(tb)))
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  let slides = reopened.slides()
  assert_eq(slides.length(), 1)
  match slides[0].shapes[0] {
    AutoShape(a) => assert_eq(a.text_body.unwrap().plain_text(), "Immutable!")
    _ => fail("expected AutoShape")
  }
}

///|
test "Presentation::clone: cloned package mutation doesn't reach original" {
  let prs0 = @presentation.Presentation::new()
  let prs1 = prs0.clone()
  // Mutate the clone via the existing `_mut` API.
  let _ = prs1.add_slide_mut(0)
  assert_eq(prs0.slides().length(), 0)
  assert_eq(prs1.slides().length(), 1)
}

///|
test "with_added_slide: out-of-range layout raises Malformed" {
  let prs = @presentation.Presentation::new()
  let r = try? prs.with_added_slide(layout_index=99)
  assert_true(r is Err(@presentation.PptxError::Malformed(_)))
}
