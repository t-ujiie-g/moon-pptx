// Slide insertion tests.

///|
test "add_slide_mut: appends a slide to an empty deck" {
  let prs = @presentation.Presentation::new()
  // Layout 0 in Presentation::new() is the Blank layout.
  let new_name = prs.add_slide_mut(0)
  assert_eq(new_name, "/ppt/slides/slide1.xml")
  // The slide should now appear via slides() and presentation_part().
  assert_eq(prs.slides().length(), 1)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_ids.length(), 1)
  assert_eq(pres.sld_ids[0].id, 256L)
}

///|
test "add_slide_mut: subsequent calls produce slide2, slide3, …" {
  let prs = @presentation.Presentation::new()
  let n1 = prs.add_slide_mut(0)
  let n2 = prs.add_slide_mut(0)
  let n3 = prs.add_slide_mut(0)
  assert_eq(n1, "/ppt/slides/slide1.xml")
  assert_eq(n2, "/ppt/slides/slide2.xml")
  assert_eq(n3, "/ppt/slides/slide3.xml")
  assert_eq(prs.slides().length(), 3)
}

///|
test "add_slide_mut: sldIds are monotonically increasing from 256" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_ids[0].id, 256L)
  assert_eq(pres.sld_ids[1].id, 257L)
  assert_eq(pres.sld_ids[2].id, 258L)
}

///|
test "add_slide_mut: presentation.xml.rels gains a rel per slide" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let pres_rels = prs.pkg.relationships_for("/ppt/presentation.xml")
  let slide_rels = pres_rels.by_type(@opc.rt_slide)
  assert_eq(slide_rels.length(), 2)
}

///|
test "add_slide_mut: new slide.xml.rels points at the layout" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let slide_rels = prs.pkg.relationships_for("/ppt/slides/slide1.xml")
  assert_eq(slide_rels.items.length(), 1)
  assert_eq(slide_rels.items[0].rel_type, @opc.rt_slide_layout)
  // Relative, not absolute: OPC resolves it against /ppt/slides/.
  assert_eq(slide_rels.items[0].target, "../slideLayouts/slideLayout1.xml")
}

///|
test "add_slide_mut: save → reopen round-trips" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  assert_eq(reopened.slides().length(), 2)
  let pres = reopened.presentation_part().unwrap()
  assert_eq(pres.sld_ids.length(), 2)
}

///|
test "add_slide_mut: out-of-range layout index raises Malformed" {
  let prs = @presentation.Presentation::new()
  try prs.add_slide_mut(5) catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "add_slides_mut appends a batch and matches one-at-a-time output" {
  let batch = @presentation.Presentation::new()
  let names = batch.add_slides_mut(0, 3)
  assert_eq(names.length(), 3)
  assert_eq(batch.slide_count(), 3)
  // The same deck built one slide at a time — same parts, same order.
  let one_by_one = @presentation.Presentation::new()
  for _ in 0..<3 {
    let _ = one_by_one.add_slide_mut(0)
  }
  assert_eq(one_by_one.slide_count(), 3)
  let batch_names = []
  for i in 0..<3 {
    batch_names.push(names[i])
  }
  assert_true(
    batch_names ==
    [
      "/ppt/slides/slide1.xml", "/ppt/slides/slide2.xml", "/ppt/slides/slide3.xml",
    ],
  )
  // Both reopen with the same slide count, which is what the sldIdLst,
  // the rels and the content types all have to agree on.
  assert_eq(
    @presentation.Presentation::open(batch.save()).slide_count(),
    @presentation.Presentation::open(one_by_one.save()).slide_count(),
  )
}

///|
test "add_slides_mut appends onto an existing deck" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let names = prs.add_slides_mut(0, 2)
  assert_eq(prs.slide_count(), 3)
  assert_eq(names[0], "/ppt/slides/slide2.xml")
  assert_eq(names[1], "/ppt/slides/slide3.xml")
  // Every slide resolves after a round-trip, so no rId or override was
  // skipped while the counters were stepped locally.
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.slides().length(), 3)
}

///|
test "add_slides_mut with a non-positive count does nothing" {
  let prs = @presentation.Presentation::new()
  assert_eq(prs.add_slides_mut(0, 0).length(), 0)
  assert_eq(prs.add_slides_mut(0, -5).length(), 0)
  assert_eq(prs.slide_count(), 0)
}
