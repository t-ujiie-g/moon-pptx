// RunProperties parser tests.

///|
/// Build a slide with one auto-shape whose `<p:txBody>` contains a single
/// paragraph with a single run whose `<a:rPr>` body is `rpr_body`.
fn slide_with_rpr(rpr_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody><a:p><a:r>" +
    rpr_body +
    "<a:t>x</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
fn rpr_of(s : @slide.Slide) -> @slide.RunProperties {
  match s.shapes[0] {
    AutoShape(sp) =>
      match sp.text_body.unwrap().paragraphs[0].content[0] {
        RunContent(r) => r.properties
        _ => abort("expected Run")
      }
    _ => abort("expected AutoShape")
  }
}

// --- attributes ---

///|
test "rPr: lang attribute captured" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr lang=\"en-US\"/>"))
  assert_eq(rpr_of(slide).lang, "en-US")
}

///|
test "rPr: sz attribute converts 1/100 pt to Pt" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr sz=\"2400\"/>"))
  assert_eq(rpr_of(slide).font_size.unwrap(), @units.Pt(24.0))
}

///|
test "rPr: b/i/u attributes" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr b=\"1\" i=\"1\" u=\"sng\"/>"),
  )
  let p = rpr_of(slide)
  assert_eq(p.bold.unwrap(), true)
  assert_eq(p.italic.unwrap(), true)
  assert_true(p.underline.unwrap() is @slide.UnderlineKind::UlSingle)
}

///|
test "rPr: b='0' is false (not None)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr b=\"0\"/>"))
  assert_eq(rpr_of(slide).bold.unwrap(), false)
}

///|
test "rPr: b='true' / b='false' accepted" {
  let s1 = @slide.Slide::parse(slide_with_rpr("<a:rPr b=\"true\"/>"))
  assert_eq(rpr_of(s1).bold.unwrap(), true)
  let s2 = @slide.Slide::parse(slide_with_rpr("<a:rPr b=\"false\"/>"))
  assert_eq(rpr_of(s2).bold.unwrap(), false)
}

///|
test "rPr: strike attribute" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr strike=\"sngStrike\"/>"),
  )
  assert_true(
    rpr_of(slide).strikethrough.unwrap() is @slide.StrikeKind::StSingle,
  )
}

///|
test "rPr: cap attribute" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr cap=\"all\"/>"))
  assert_true(rpr_of(slide).caps.unwrap() is @slide.CapsKind::CapsAll)
}

///|
test "rPr: baseline as Percentage (subscript/superscript)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr baseline=\"30000\"/>"))
  // 30000 OOXML units = 30%
  assert_eq(rpr_of(slide).baseline.unwrap(), @units.Percentage(30.0))
}

///|
test "rPr: baseline negative for subscript" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr baseline=\"-25000\"/>"),
  )
  assert_eq(rpr_of(slide).baseline.unwrap(), @units.Percentage(-25.0))
}

// --- children ---

///|
test "rPr: latin / ea / cs font typefaces" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:latin typeface=\"Calibri\"/>" +
      "<a:ea typeface=\"Yu Gothic\"/>" +
      "<a:cs typeface=\"\"/></a:rPr>",
    ),
  )
  let p = rpr_of(slide)
  assert_eq(p.latin.unwrap(), "Calibri")
  assert_eq(p.east_asian.unwrap(), "Yu Gothic")
  assert_eq(p.complex_script.unwrap(), "")
}

///|
test "rPr: solidFill with srgbClr" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:rPr>",
    ),
  )
  match rpr_of(slide).fill.unwrap().base {
    Srgb(c) => assert_eq(c.to_hex(), "FF0000")
    _ => fail("expected Srgb base")
  }
}

///|
test "rPr: solidFill with schemeClr" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:solidFill><a:schemeClr val=\"accent2\"/></a:solidFill></a:rPr>",
    ),
  )
  match rpr_of(slide).fill.unwrap().base {
    Scheme(t) => assert_true(t is @units.ThemeColor::Accent2)
    _ => fail("expected Scheme base")
  }
}

///|
test "rPr: hlinkClick captures r:id" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr><a:hlinkClick r:id=\"rId5\"/></a:rPr>"),
  )
  assert_eq(rpr_of(slide).hyperlink_click.unwrap(), "rId5")
}

// --- error / absent ---

///|
test "rPr: missing attributes leave fields None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr/>"))
  let p = rpr_of(slide)
  assert_true(p.font_size is None)
  assert_true(p.bold is None)
  assert_true(p.italic is None)
  assert_true(p.underline is None)
  assert_true(p.strikethrough is None)
  assert_true(p.baseline is None)
  assert_true(p.caps is None)
  assert_true(p.latin is None)
  assert_true(p.east_asian is None)
  assert_true(p.complex_script is None)
  assert_true(p.fill is None)
  assert_true(p.hyperlink_click is None)
}

///|
test "rPr: gradFill and effectLst are skipped without raising" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr>" +
      "<a:gradFill><a:gsLst><a:gs pos=\"0\"/></a:gsLst></a:gradFill>" +
      "<a:effectLst><a:outerShdw blurRad=\"38100\"/></a:effectLst>" +
      "</a:rPr>",
    ),
  )
  // No fill should be picked up from gradFill — run-level fills only
  // pick up solidFill; gradient + pattern + blip run-fills are an
  // intentional expansion point. effectLst rides on `extension` (lifting
  // it waits on lift-safe @oxml effect parsers — F3 follow-up).
  assert_true(rpr_of(slide).fill is None)
}

///|
test "rPr: unknown underline value collapses to None (graceful)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr u=\"weirdValue\"/>"))
  assert_true(rpr_of(slide).underline is None)
}

// --- character spacing (spc) — issue #7 ---

///|
test "rPr: spc attribute converts 1/100 pt to Pt" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr spc=\"150\"/>"))
  assert_eq(rpr_of(slide).character_spacing.unwrap(), @units.Pt(1.5))
}

///|
test "rPr: negative spc (tightening) parses" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr spc=\"-50\"/>"))
  assert_eq(rpr_of(slide).character_spacing.unwrap(), @units.Pt(-0.5))
}

///|
test "rPr: absent spc is None (behaviour unchanged)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr sz=\"2400\"/>"))
  assert_true(rpr_of(slide).character_spacing is None)
}

///|
test "rPr: spc survives a parse -> serialize -> parse round-trip" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr spc=\"120\"/>"))
  let reparsed = @slide.Slide::parse(slide.serialize())
  assert_eq(rpr_of(reparsed).character_spacing.unwrap(), @units.Pt(1.2))
}

///|
test "builder: with_character_spacing emits spc and round-trips" {
  let rp = @slide.RunProperties::default().with_character_spacing(
    @units.Pt(2.0),
  )
  let body = @slide.TextBody::of_styled_text("tracked", rp)
  let shape = @slide.AutoShape::textbox(
    2,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    "",
  ).with_text_body(body)
  // An empty base slide to drop the built shape onto.
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(base_xml)).with_shape(
    @slide.AutoShape(shape),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  assert_eq(rpr_of(reparsed).character_spacing.unwrap(), @units.Pt(2.0))
}

// --- kerning (kern) + highlight — roadmap v0.6 F3 (slice 1) ---

///|
test "rPr: kern attribute converts 1/100 pt to Pt" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr kern=\"1200\"/>"))
  assert_eq(rpr_of(slide).kerning.unwrap(), @units.Pt(12.0))
}

///|
test "rPr: absent kern is None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr sz=\"2400\"/>"))
  assert_true(rpr_of(slide).kerning is None)
}

///|
test "rPr: kern survives parse -> serialize -> parse" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr kern=\"800\"/>"))
  let reparsed = @slide.Slide::parse(slide.serialize())
  assert_eq(rpr_of(reparsed).kerning.unwrap(), @units.Pt(8.0))
}

///|
test "rPr: highlight colour parses into the typed field" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:highlight><a:srgbClr val=\"FFFF00\"/></a:highlight></a:rPr>",
    ),
  )
  assert_eq(
    rpr_of(slide).highlight.unwrap(),
    @oxml.Color::srgb(@units.RgbColor::parse_hex("FFFF00")),
  )
}

///|
test "rPr: absent highlight is None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr/>"))
  assert_true(rpr_of(slide).highlight is None)
}

///|
test "builder: with_kerning + with_highlight emit and round-trip" {
  let rp = @slide.RunProperties::default()
    .with_kerning(@units.Pt(10.0))
    .with_highlight(@units.RgbColor::new(0xFF, 0xCC, 0x00))
  let body = @slide.TextBody::of_styled_text("hi", rp)
  let shape = @slide.AutoShape::textbox(
    2,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    "",
  ).with_text_body(body)
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(base_xml)).with_shape(
    @slide.AutoShape(shape),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  let got = rpr_of(reparsed)
  assert_eq(got.kerning.unwrap(), @units.Pt(10.0))
  assert_eq(
    got.highlight.unwrap(),
    @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0xCC, 0x00)),
  )
}
