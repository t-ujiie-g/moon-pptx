// Slide deletion tests (roadmap v0.3.1 E1).

///|
test "remove_slide_mut: drops the targeted slide and its sldId" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  assert_eq(prs.slides().length(), 3)
  // Remove the middle slide.
  prs.remove_slide_mut(1)
  assert_eq(prs.slides().length(), 2)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_ids.length(), 2)
  // The slide2 part + its rels + content-type override are gone.
  assert_true(prs.pkg.part_by_name("/ppt/slides/slide2.xml") is None)
  assert_true(prs.pkg.part_by_name("/ppt/slides/_rels/slide2.xml.rels") is None)
  let has_override = prs.pkg.content_types().overrides
    .iter()
    .any(fn(kv) { kv.0 == "/ppt/slides/slide2.xml" })
  assert_false(has_override)
}

///|
test "remove_slide_mut: presentation.xml.rels loses exactly one slide rel" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  prs.remove_slide_mut(0)
  let pres_rels = prs.pkg.relationships_for("/ppt/presentation.xml")
  assert_eq(pres_rels.by_type(@opc.rt_slide).length(), 1)
}

///|
test "remove_slide_mut: save → reopen round-trips the smaller deck" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  prs.remove_slide_mut(2)
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.slides().length(), 2)
  assert_eq(reopened.presentation_part().unwrap().sld_ids.length(), 2)
  // Shared structural parts survive.
  assert_true(
    reopened.pkg.part_by_name("/ppt/slideLayouts/slideLayout1.xml") is Some(_),
  )
  assert_true(
    reopened.pkg.part_by_name("/ppt/slideMasters/slideMaster1.xml") is Some(_),
  )
  assert_true(reopened.pkg.part_by_name("/ppt/theme/theme1.xml") is Some(_))
}

///|
test "remove_slide_mut: clearing every slide leaves a valid empty deck" {
  // The "replaceSlides" use case: strip all template slides, keep the
  // master / layout / theme skeleton.
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  // Remove from the front each time; indices shift down.
  prs.remove_slide_mut(0)
  prs.remove_slide_mut(0)
  assert_eq(prs.slides().length(), 0)
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.slides().length(), 0)
  assert_eq(reopened.slide_layouts().length(), 1)
  assert_eq(reopened.slide_masters().length(), 1)
}

///|
test "remove_slide_mut: garbage-collects a slide-private image" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
  prs.remove_slide_mut(0)
  // The image was reachable only from the removed slide → collected.
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is None)
}

///|
test "remove_slide_mut: keeps an image still referenced by another slide" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  // Put the same image on both slides — each add_picture_mut creates a
  // distinct media part, so to model sharing we add one image to each
  // slide and assert removal of slide 0 leaves slide 1's image intact.
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.add_picture_mut(
    1,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  // slide1 → image1, slide2 → image2.
  prs.remove_slide_mut(0)
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is None)
  assert_true(prs.pkg.part_by_name("/ppt/media/image2.png") is Some(_))
}

///|
test "remove_slide_mut: garbage-collects the slide's notes" {
  // notesSlide carries a back-reference to its slide, so a dangling one
  // is the riskiest orphan — make sure deletion sweeps it.
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "speaker notes")
  assert_true(
    prs.pkg.part_by_name("/ppt/notesSlides/notesSlide1.xml") is Some(_),
  )
  prs.remove_slide_mut(0)
  assert_true(prs.pkg.part_by_name("/ppt/notesSlides/notesSlide1.xml") is None)
  // The shared notes master is structural — it stays.
  assert_true(
    prs.pkg.part_by_name("/ppt/notesMasters/notesMaster1.xml") is Some(_),
  )
}

///|
test "remove_slide_mut: out-of-range index raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let r = try? prs.remove_slide_mut(5)
  assert_true(r is Err(@presentation.PptxError::Malformed(_)))
}

///|
test "without_slide: immutable — original keeps all slides" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let smaller = prs.without_slide(0)
  assert_eq(prs.slides().length(), 2)
  assert_eq(smaller.slides().length(), 1)
}
