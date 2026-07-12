// Tests for the run-level hyperlink builder: `RunProperties::with_hyperlink` /
// `with_hyperlink_to_slide` + the resolver hooked into `update_slide_mut`.

///|
/// Build a slide carrying one textbox with a single styled run that
/// has `target` attached. Returns the freshly-built (resolved) prs.
fn build_with_hyperlink(
  target : @slide.HyperlinkTarget,
  tooltip? : String = "",
) -> @presentation.Presentation raise @presentation.PptxError {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // If the target is InternalSlide(_), make sure there are enough slides.
  match target {
    InternalSlide(idx) =>
      while prs.slides().length() <= idx {
        let _ = prs.add_slide_mut(0)
      }
    _ => ()
  }
  let rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(24.0))
    .with_color(@units.RgbColor::new(0x33, 0x66, 0xCC))
  let rp = match target {
    ExternalUrl(url) => rp.with_hyperlink(url, tooltip~)
    InternalSlide(idx) => rp.with_hyperlink_to_slide(idx, tooltip~)
  }
  let tb = @slide.TextBody::of_styled_text("click me", rp)
  let box = @slide.AutoShape::textbox(
    2,
    "tb",
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(4_572_000L),
    @units.Emu(914_400L),
    "",
  ).with_text_body(tb)
  let s = prs.slides()[0]
  prs.update_slide_mut(0, s.with_shape(@slide.AutoShape(box)))
  prs
}

///|
test "with_hyperlink: external URL registers a TargetMode::External rel" {
  let prs = build_with_hyperlink(ExternalUrl("https://example.com"))
  // The slide rels should now carry exactly one new hyperlink rel.
  let slide_name = prs.pkg
    .parts()
    .iter()
    .filter(fn(p) {
      p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml")
    })
    .head()
    .unwrap().name
  let rels = prs.pkg.relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  assert_eq(hl.target, "https://example.com")
  assert_true(hl.target_mode is External)
}

///|
test "with_hyperlink: rId surfaces in re-parsed run's hyperlink_click" {
  let prs = build_with_hyperlink(ExternalUrl("https://example.com"))
  let slide = prs.slides()[0]
  let auto = match slide.shapes[0] {
    AutoShape(a) => a
    _ => fail("expected AutoShape")
  }
  let tb = auto.text_body.unwrap()
  let p0 = tb.paragraphs[0]
  let r0 = match p0.content[0] {
    RunContent(r) => r
    _ => fail("expected RunContent")
  }
  // hyperlink_click is set (rId) and hyperlink_target is gone after
  // a parse cycle — the parser doesn't reconstruct unresolved targets.
  assert_true(r0.properties.hyperlink_click is Some(_))
  assert_true(r0.properties.hyperlink_target is None)
}

///|
test "with_hyperlink: tooltip survives round-trip" {
  let prs = build_with_hyperlink(
    ExternalUrl("https://example.com"),
    tooltip="See more",
  )
  let slide = prs.slides()[0]
  let auto = match slide.shapes[0] {
    AutoShape(a) => a
    _ => fail("expected AutoShape")
  }
  let r0 = match auto.text_body.unwrap().paragraphs[0].content[0] {
    RunContent(r) => r
    _ => fail("expected RunContent")
  }
  assert_true(r0.properties.hyperlink_tooltip is Some("See more"))
}

///|
test "with_hyperlink_to_slide: registers Internal rel pointing at target slide" {
  let prs = build_with_hyperlink(InternalSlide(1))
  // Find the slide part that carries our new rt_slide rel. (We
  // updated slide_idx=0 → its part's `.rels` must own one rt_slide
  // entry, no matter the package's part-storage order.)
  let mut to_slide : @opc.Relationship? = None
  for p in prs.pkg.parts() {
    if p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml") {
      let arr = prs.pkg.relationships_for(p.name).by_type(@opc.rt_slide)
      if arr.length() > 0 {
        to_slide = Some(arr[0])
        break
      }
    }
  }
  let to_slide = to_slide.unwrap()
  assert_true(to_slide.target_mode is Internal)
  // Target is the other slide's filename (relative-target math).
  assert_true(to_slide.target.has_suffix("slide2.xml"))
}

///|
test "no hyperlinks → no rels mutation, no extra relationship lookups" {
  // Build a slide with a plain text run. update_slide_mut should
  // short-circuit; the rels should match the freshly-added-slide state.
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let slide_name = prs.pkg
    .parts()
    .iter()
    .filter(fn(p) {
      p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml")
    })
    .head()
    .unwrap().name
  let before = prs.pkg.relationships_for(slide_name).items.length()
  let rp = @slide.RunProperties::default().with_font_size(@units.Pt(20.0))
  let tb = @slide.TextBody::of_styled_text("hello", rp)
  let box = @slide.AutoShape::textbox(
    2,
    "tb",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1L),
    @units.Emu(1L),
    "",
  ).with_text_body(tb)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(box)))
  let after = prs.pkg.relationships_for(slide_name).items.length()
  assert_eq(before, after)
}

///|
test "with_hyperlink_to_slide: out-of-range raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let rp = @slide.RunProperties::default().with_hyperlink_to_slide(99)
  let tb = @slide.TextBody::of_styled_text("oops", rp)
  let box = @slide.AutoShape::textbox(
    2,
    "tb",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1L),
    @units.Emu(1L),
    "",
  ).with_text_body(tb)
  try
    prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(box)))
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "with_hyperlink: full save → reopen → rels survive" {
  let prs = build_with_hyperlink(
    ExternalUrl("https://moonbitlang.com"),
    tooltip="docs",
  )
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let slide_name = prs2.pkg
    .parts()
    .iter()
    .filter(fn(p) {
      p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml")
    })
    .head()
    .unwrap().name
  let rels = prs2.pkg.relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  assert_eq(hl.target, "https://moonbitlang.com")
  // Tooltip on `<a:hlinkClick tooltip="…">` round-trips.
  let r0 = match prs2.slides()[0].shapes[0] {
    AutoShape(a) =>
      match a.text_body.unwrap().paragraphs[0].content[0] {
        RunContent(r) => r
        _ => fail("expected RunContent")
      }
    _ => fail("expected AutoShape")
  }
  assert_true(r0.properties.hyperlink_tooltip is Some("docs"))
}
