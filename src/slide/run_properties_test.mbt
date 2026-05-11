// RunProperties parser tests (Phase 3d2).

///|
let rp_pml : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
let rp_a : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
let rp_r : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

///|
fn rp_ascii(s : String) -> FixedArray[Byte] {
  let chars = s.to_array()
  let bytes = FixedArray::make(chars.length(), b'\x00')
  let mut i = 0
  while i < chars.length() {
    bytes[i] = chars[i].to_int().to_byte()
    i = i + 1
  }
  bytes
}

///|
/// Build a slide with one auto-shape whose `<p:txBody>` contains a single
/// paragraph with a single run whose `<a:rPr>` body is `rpr_body`.
fn slide_with_rpr(rpr_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    rp_pml +
    "\" xmlns:a=\"" +
    rp_a +
    "\" xmlns:r=\"" +
    rp_r +
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
  rp_ascii(xml)
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
  match rpr_of(slide).fill.unwrap() {
    SolidRgb(c) => assert_eq(c.to_hex(), "FF0000")
    _ => fail("expected SolidRgb")
  }
}

///|
test "rPr: solidFill with schemeClr" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:solidFill><a:schemeClr val=\"accent2\"/></a:solidFill></a:rPr>",
    ),
  )
  match rpr_of(slide).fill.unwrap() {
    SolidTheme(t) => assert_true(t is @units.ThemeColor::Accent2)
    _ => fail("expected SolidTheme")
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
  // No fill should be picked up from gradFill — that's an intentional Phase 3e
  // expansion point.
  assert_true(rpr_of(slide).fill is None)
}

///|
test "rPr: unknown underline value collapses to None (graceful)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr u=\"weirdValue\"/>"))
  assert_true(rpr_of(slide).underline is None)
}
