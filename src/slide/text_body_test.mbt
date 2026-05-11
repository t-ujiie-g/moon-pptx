// Text body parser tests (Phase 3d1).

///|
/// Build a slide containing a single auto-shape whose `<p:txBody>` body
/// is supplied verbatim.
fn slide_with_txbody(inner : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody>" +
    inner +
    "</p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
fn first_auto_shape(s : @slide.Slide) -> @slide.AutoShape {
  match s.shapes[0] {
    AutoShape(sp) => sp
    _ => abort("expected AutoShape")
  }
}

// --- happy path ---

///|
test "parse: single paragraph with a single run" {
  let inner = "<a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Hello</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.paragraphs.length(), 1)
  let p = tb.paragraphs[0]
  assert_eq(p.content.length(), 1)
  match p.content[0] {
    RunContent(r) => assert_eq(r.text, "Hello")
    _ => fail("expected Run")
  }
  assert_eq(tb.plain_text(), "Hello")
}

///|
test "parse: two paragraphs join with newline in plain_text" {
  let inner = "<a:p><a:r><a:t>Line 1</a:t></a:r></a:p>" +
    "<a:p><a:r><a:t>Line 2</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.paragraphs.length(), 2)
  assert_eq(tb.plain_text(), "Line 1\nLine 2")
}

///|
test "parse: paragraph with multiple runs concatenates text in source order" {
  let inner = "<a:p>" +
    "<a:r><a:t>Hello, </a:t></a:r>" +
    "<a:r><a:t>World</a:t></a:r>" +
    "<a:r><a:t>!</a:t></a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.paragraphs[0].content.length(), 3)
  assert_eq(tb.plain_text(), "Hello, World!")
}

///|
test "parse: run with rPr is consumed without losing text" {
  let inner = "<a:p>" +
    "<a:r>" +
    "<a:rPr lang=\"en-US\" sz=\"2400\" b=\"1\">" +
    "<a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>" +
    "<a:latin typeface=\"Calibri\"/>" +
    "</a:rPr>" +
    "<a:t>Formatted</a:t>" +
    "</a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  match first_auto_shape(slide).text_body.unwrap().paragraphs[0].content[0] {
    RunContent(r) => assert_eq(r.text, "Formatted")
    _ => fail("expected Run")
  }
}

///|
test "parse: br between runs inserts newline in plain_text" {
  let inner = "<a:p>" +
    "<a:r><a:t>A</a:t></a:r>" +
    "<a:br><a:rPr/></a:br>" +
    "<a:r><a:t>B</a:t></a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.paragraphs[0].content.length(), 3)
  assert_eq(tb.plain_text(), "A\nB")
}

///|
test "parse: fld captures id, type, and body text" {
  let inner = "<a:p>" +
    "<a:fld id=\"{F7021451-1387-4CA6-816F-3879F97B5CBC}\" type=\"slidenum\">" +
    "<a:rPr/><a:t>1</a:t>" +
    "</a:fld>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[0] {
    FieldContent(f) => {
      assert_eq(f.id, "{F7021451-1387-4CA6-816F-3879F97B5CBC}")
      assert_eq(f.field_type, "slidenum")
      assert_eq(f.text, "1")
    }
    _ => fail("expected FieldContent")
  }
}

///|
test "parse: empty paragraph is preserved (gives blank line in plain_text)" {
  let inner = "<a:p><a:r><a:t>A</a:t></a:r></a:p>" +
    "<a:p/>" +
    "<a:p><a:r><a:t>B</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.paragraphs.length(), 3)
  assert_eq(tb.paragraphs[1].content.length(), 0)
  assert_eq(tb.plain_text(), "A\n\nB")
}

///|
test "parse: bodyPr and lstStyle are silently skipped (3d4 will model them)" {
  let inner = "<a:bodyPr wrap=\"square\" anchor=\"ctr\"/>" +
    "<a:lstStyle><a:lvl1pPr/></a:lstStyle>" +
    "<a:p><a:r><a:t>X</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.plain_text(), "X")
}

///|
test "parse: shape with no txBody leaves field None" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  assert_true(first_auto_shape(slide).text_body is None)
}

///|
test "parse: text with XML-escaped characters round-trips" {
  let inner = "<a:p><a:r><a:t>&lt;a &amp; b&gt;</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  match first_auto_shape(slide).text_body.unwrap().paragraphs[0].content[0] {
    RunContent(r) => assert_eq(r.text, "<a & b>")
    _ => fail("expected Run")
  }
}
