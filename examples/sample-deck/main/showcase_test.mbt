// Guards that the sample deck is structurally sound — the library must be
// able to re-open the bytes it just produced, and the deck must carry the
// expected slide count + the second (defined) master.

///|
test "sample deck reopens with all feature slides + a defined master" {
  let prs = @presentation.Presentation::open(build_sample_deck())
  // 26 slides: title, toc, text, shapes, custom-geom, picture, table,
  // 4 chart slides, background, combo, svg, edit, media, smartart,
  // animation, online-video, v0.5.2 / v0.6 / v0.7 feature slides,
  // master, 2 typed-layout slides, closing.
  assert_eq(prs.slides().length(), 26)
  // The deck's own master + the one added by sample_master_slide.
  assert_eq(prs.slide_masters().length(), 2)
  // Every slide carries a transition.
  for s in prs.slides() {
    assert_true(s.transition is Some(_))
  }
  // The named sections partition the deck and survive the round-trip.
  let sections = prs.sections()
  assert_eq(sections.length(), 6)
  assert_eq(sections[0].title, "Introduction")
  assert_eq(sections[5].start, 22)
  // Both docProps parts carry their fields.
  assert_eq(prs.app_properties().company.unwrap(), "moon-pptx project")
  assert_eq(
    prs.core_properties().title.unwrap(),
    "moon-pptx feature sample deck",
  )
  // The combo chart's embedded data workbook is in the package.
  assert_true(
    prs.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
  )
}

///|
test "each isolated feature deck reopens cleanly" {
  // Mirrors the CLI split mode: title + one feature must round-trip.
  for i in 0..<22 {
    let prs = @presentation.Presentation::open(build_sample_isolated(i))
    assert_true(prs.slides().length() >= 1)
  }
}
