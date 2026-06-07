// Slide duplication tests (roadmap v0.3.1 E3).
//
// `stamp_slide` / `marker_of` are shared with move_slide_test.mbt (same
// blackbox test package).

///|
test "duplicate_slide_mut: appends an identical copy" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "Orig")
  let new_name = prs.duplicate_slide_mut(0)
  assert_eq(new_name, "/ppt/slides/slide2.xml")
  let slides = prs.slides()
  assert_eq(slides.length(), 2)
  assert_eq(marker_of(slides[0]), "Orig")
  assert_eq(marker_of(slides[1]), "Orig")
}

///|
test "duplicate_slide_mut: new sldId + presentation rel are wired" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.duplicate_slide_mut(0)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_ids.length(), 2)
  // Distinct slide ids.
  assert_true(pres.sld_ids[0].id != pres.sld_ids[1].id)
  let pres_rels = prs.pkg.relationships_for("/ppt/presentation.xml")
  assert_eq(pres_rels.by_type(@opc.rt_slide).length(), 2)
}

///|
test "duplicate_slide_mut: clone re-references the source's parts" {
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
  let new_name = prs.duplicate_slide_mut(0)
  // Only one image part exists — the clone shares it (Q12: re-reference).
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
  assert_true(prs.pkg.part_by_name("/ppt/media/image2.png") is None)
  // Both slides' .rels point at the same image target.
  let orig_rels = prs.pkg.relationships_for("/ppt/slides/slide1.xml")
  let clone_rels = prs.pkg.relationships_for(new_name)
  assert_eq(
    orig_rels.by_type(@opc.rt_image).length(),
    clone_rels.by_type(@opc.rt_image).length(),
  )
  assert_eq(clone_rels.by_type(@opc.rt_image)[0].target, "../media/image1.png")
}

///|
test "duplicate_slide_mut: save → reopen round-trips both slides" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "dupme")
  let _ = prs.duplicate_slide_mut(0)
  let reopened = @presentation.Presentation::open(prs.save())
  let slides = reopened.slides()
  assert_eq(slides.length(), 2)
  assert_eq(marker_of(slides[0]), "dupme")
  assert_eq(marker_of(slides[1]), "dupme")
}

///|
test "duplicate_slide_mut: shared image survives deleting the original" {
  // E1 + E3 together: a clone keeps a shared part alive when the source
  // slide is removed (reference-counted GC sees the clone's reference).
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
  let _ = prs.duplicate_slide_mut(0)
  prs.remove_slide_mut(0)
  assert_eq(prs.slides().length(), 1)
  // The clone still references image1.png, so it must NOT be collected.
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
}

///|
test "duplicate_slide_mut: out-of-range index raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try prs.duplicate_slide_mut(7) catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "with_duplicated_slide: immutable — original unchanged" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let (bigger, name) = prs.with_duplicated_slide(0)
  assert_eq(name, "/ppt/slides/slide2.xml")
  assert_eq(prs.slides().length(), 1)
  assert_eq(bigger.slides().length(), 2)
}
