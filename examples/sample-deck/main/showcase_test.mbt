// Guards that the sample deck is structurally sound — the library must be
// able to re-open the bytes it just produced, and the deck must carry the
// expected slide count + the second (defined) master.

///|
test "sample deck reopens with all feature slides + a defined master" {
  let prs = @presentation.Presentation::open(build_sample_deck())
  // 25 slides: title, toc, text, shapes, custom-geom, picture, table,
  // 4 chart slides, background, combo, svg, edit, media, smartart, animation,
  // online-video, v0.5.2 features, v0.6 features, master, 2 typed-layout
  // slides (M1), closing.
  assert_eq(prs.slides().length(), 25)
  // The deck's own master + the one added by sample_master_slide.
  assert_eq(prs.slide_masters().length(), 2)
  // Every slide carries a transition (v0.4 D3).
  for s in prs.slides() {
    assert_true(s.transition is Some(_))
  }
}

///|
test "each isolated feature deck reopens cleanly" {
  // Mirrors the CLI split mode: title + one feature must round-trip.
  for i in 0..<21 {
    let prs = @presentation.Presentation::open(build_sample_isolated(i))
    assert_true(prs.slides().length() >= 1)
  }
}
