// Slide insertion tests — Phase 5c.

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
  let slide_rels = pres_rels.by_type(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide",
  )
  assert_eq(slide_rels.length(), 2)
}

///|
test "add_slide_mut: new slide.xml.rels points at the layout" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let slide_rels = prs.pkg.relationships_for("/ppt/slides/slide1.xml")
  assert_eq(slide_rels.items.length(), 1)
  assert_eq(
    slide_rels.items[0].rel_type,
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout",
  )
  // Target is relative — `../slideLayouts/slideLayout1.xml`.
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
  let r = try? prs.add_slide_mut(5)
  assert_true(r is Err(@presentation.PptxError::Malformed(_)))
}
