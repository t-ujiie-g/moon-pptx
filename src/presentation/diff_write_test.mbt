// Lossless diff-write regression.
//
// `Presentation` retains each part's *source bytes* (the OPC layer stores
// raw ZIP-entry bytes; only `_mut` operations replace a part's bytes), so
// `save()` re-emits untouched parts verbatim by
// construction, with no dirty-tracking or hashing. These tests lock that in:
// editing one slide must leave every other part byte-for-byte identical,
// which is what preserves a real-world Office deck's exact formatting on the
// parts you didn't touch.

///|
fn bytes_eq(a : FixedArray[Byte], b : FixedArray[Byte]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn part_bytes(
  prs : @presentation.Presentation,
  name : String,
) -> FixedArray[Byte] {
  prs.pkg.part_by_name(name).unwrap().bytes
}

///|
test "editing one slide leaves every other part byte-for-byte identical" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  // Put real content on slide 1 so `original` is a non-trivial deck.
  let r0 = @slide.AutoShape::rect(
    2,
    "A",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(r0)))
  let original = prs.save()

  // Reopen and edit ONLY slide 2.
  let editing = @presentation.Presentation::open(original)
  let r1 = @slide.AutoShape::rect(
    2,
    "B",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(200L),
    @units.Emu(200L),
  )
  editing.update_slide_mut(
    1,
    editing.slides()[1].with_shape(@slide.AutoShape(r1)),
  )
  let edited = editing.save()

  // Compare the two outputs part-by-part.
  let o = @presentation.Presentation::open(original)
  let e = @presentation.Presentation::open(edited)
  // Untouched parts are re-emitted verbatim:
  for
    name in [
      "/ppt/slides/slide1.xml", // the slide we didn't touch
       "/ppt/theme/theme1.xml", "/ppt/slideMasters/slideMaster1.xml", "/ppt/slideLayouts/slideLayout1.xml",
      "/ppt/presentation.xml", // slide order unchanged → not rewritten
       "/ppt/presProps.xml",
    ] {
    assert_true(bytes_eq(part_bytes(o, name), part_bytes(e, name)))
  }
  // The edited slide genuinely changed:
  assert_false(
    bytes_eq(
      part_bytes(o, "/ppt/slides/slide2.xml"),
      part_bytes(e, "/ppt/slides/slide2.xml"),
    ),
  )
}

///|
test "open → save with no edits preserves every part byte-for-byte" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let original = prs.save()
  // A pure round-trip (no mutations) must not re-serialise anything.
  let resaved = @presentation.Presentation::open(original).save()
  let o = @presentation.Presentation::open(original)
  let r = @presentation.Presentation::open(resaved)
  for
    name in [
      "/ppt/slides/slide1.xml", "/ppt/theme/theme1.xml", "/ppt/slideMasters/slideMaster1.xml",
      "/ppt/presentation.xml", "/[Content_Types].xml",
    ] {
    assert_true(bytes_eq(part_bytes(o, name), part_bytes(r, name)))
  }
}
