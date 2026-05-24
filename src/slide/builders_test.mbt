// Shape / slide builder tests.

///|
test "AutoShape::rect: produces expected preset + transform" {
  let s = @slide.AutoShape::rect(
    42,
    "MyRect",
    @units.Emu(100L),
    @units.Emu(200L),
    @units.Emu(300L),
    @units.Emu(400L),
  )
  assert_eq(s.id, 42)
  assert_eq(s.name, "MyRect")
  let xfrm = s.transform.unwrap()
  assert_eq(xfrm.offset.x, @units.Emu(100L))
  assert_eq(xfrm.offset.y, @units.Emu(200L))
  assert_eq(xfrm.extent.cx, @units.Emu(300L))
  assert_eq(xfrm.extent.cy, @units.Emu(400L))
  match s.geometry.unwrap() {
    Preset(p, adj) => {
      assert_true(p == @slide.PresetShape::Rect)
      assert_eq(adj.length(), 0)
    }
    _ => fail("expected Preset geometry")
  }
  assert_true(s.text_body is None)
}

///|
test "AutoShape::ellipse / round_rect: vary only the preset enum" {
  let e = @slide.AutoShape::ellipse(
    1,
    "E",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1L),
    @units.Emu(1L),
  )
  match e.geometry.unwrap() {
    Preset(p, _) => assert_true(p == @slide.PresetShape::Ellipse)
    _ => fail("expected Ellipse")
  }
  let r = @slide.AutoShape::round_rect(
    2,
    "R",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1L),
    @units.Emu(1L),
  )
  match r.geometry.unwrap() {
    Preset(p, _) => assert_true(p == @slide.PresetShape::RoundRect)
    _ => fail("expected RoundRect")
  }
}

///|
test "AutoShape::textbox: rect geometry + text body" {
  let tb = @slide.AutoShape::textbox(
    7,
    "T1",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1L),
    @units.Emu(1L),
    "Hello",
  )
  match tb.geometry.unwrap() {
    Preset(p, _) => assert_true(p == @slide.PresetShape::Rect)
    _ => fail("expected Rect geometry on text box")
  }
  let body = tb.text_body.unwrap()
  assert_eq(body.plain_text(), "Hello")
}

///|
test "TextBody::of_text: single paragraph with one run" {
  let body = @slide.TextBody::of_text("Hi there")
  assert_eq(body.paragraphs.length(), 1)
  assert_eq(body.paragraphs[0].content.length(), 1)
  assert_eq(body.plain_text(), "Hi there")
}

///|
test "Slide::with_shape: appends shape; original unchanged" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld name=\"S\"><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let original = @slide.Slide::parse(fixture_bytes(xml))
  assert_eq(original.shapes.length(), 0)
  let rect = @slide.AutoShape::rect(
    2,
    "R",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let modified = original.with_shape(@slide.AutoShape(rect))
  assert_eq(modified.shapes.length(), 1)
  // The original slide's shapes array stays empty — `with_shape`
  // copies before pushing.
  assert_eq(original.shapes.length(), 0)
}

///|
test "AutoShape: structural fields survive Slide::serialize" {
  // Build a slide from scratch with one rect shape and confirm the
  // structural fields survive serialize → re-parse.
  //
  // Strict `==` doesn't hold on the first round-trip because the
  // parser captures `<p:cNvPr>` / `<p:cNvSpPr>` / `<p:nvPr>` into
  // `extension` wholesale — the hand-built AutoShape starts with an
  // empty extension array, while the reparsed copy gains those
  // captured wrappers. Subsequent round-trips are Eq-stable (see
  // the "second round-trip is stable" test below).
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(fixture_bytes(xml))
  let rect = @slide.AutoShape::rect(
    2,
    "R",
    @units.Emu(100L),
    @units.Emu(200L),
    @units.Emu(300L),
    @units.Emu(400L),
  )
  let s = base.with_shape(@slide.AutoShape(rect))
  let bytes = s.serialize()
  let s_reparsed = @slide.Slide::parse(bytes)
  assert_eq(s_reparsed.shapes.length(), 1)
  match s_reparsed.shapes[0] {
    AutoShape(a) => {
      assert_eq(a.id, 2)
      assert_eq(a.name, "R")
      let xfrm = a.transform.unwrap()
      assert_eq(xfrm.offset.x, @units.Emu(100L))
      assert_eq(xfrm.extent.cx, @units.Emu(300L))
      match a.geometry.unwrap() {
        Preset(p, _) => assert_true(p == @slide.PresetShape::Rect)
        _ => fail("expected Rect preset")
      }
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "AutoShape: second round-trip is Eq-stable" {
  // Once a hand-built shape has been through one parse cycle the
  // captured wrappers are populated, and every subsequent
  // serialize → parse cycle holds `==`.
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(fixture_bytes(xml))
  let rect = @slide.AutoShape::rect(
    2,
    "R",
    @units.Emu(100L),
    @units.Emu(200L),
    @units.Emu(300L),
    @units.Emu(400L),
  )
  let s_first = @slide.Slide::parse(
    base.with_shape(@slide.AutoShape(rect)).serialize(),
  )
  let s_second = @slide.Slide::parse(s_first.serialize())
  assert_true(s_first == s_second)
}
