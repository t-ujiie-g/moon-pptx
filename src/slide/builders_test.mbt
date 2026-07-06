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
test "RunProperties: fluent setters chain" {
  let rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(24.0))
    .with_bold()
    .with_italic()
    .with_font("Helvetica")
    .with_color(@units.RgbColor::new(0x10, 0x20, 0x30))
  assert_eq(rp.font_size.unwrap(), @units.Pt(24.0))
  assert_eq(rp.bold.unwrap(), true)
  assert_eq(rp.italic.unwrap(), true)
  assert_eq(rp.latin.unwrap(), "Helvetica")
  assert_true(rp.fill is Some(_))
}

///|
test "RunProperties: fluent setters do not mutate the original" {
  let base = @slide.RunProperties::default()
  let bigger = base.with_font_size(@units.Pt(36.0))
  assert_true(base.font_size is None)
  assert_eq(bigger.font_size.unwrap(), @units.Pt(36.0))
}

///|
test "Paragraph::with_alignment: lifts to alignment field" {
  let p = @slide.Paragraph::of_text("Centred").with_alignment(AlignCenter)
  assert_true(p.properties.alignment is Some(AlignCenter))
}

///|
test "TextBody::of_styled_text: run carries the styling" {
  let rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(18.0))
    .with_bold()
  let body = @slide.TextBody::of_styled_text("Bold 18", rp)
  assert_eq(body.paragraphs.length(), 1)
  match body.paragraphs[0].content[0] {
    RunContent(r) => {
      assert_eq(r.text, "Bold 18")
      assert_eq(r.properties.font_size.unwrap(), @units.Pt(18.0))
      assert_eq(r.properties.bold.unwrap(), true)
    }
    _ => fail("expected RunContent")
  }
}

///|
test "TextBody::of_paragraphs: passes through" {
  let p0 = @slide.Paragraph::of_text("one")
  let p1 = @slide.Paragraph::of_text("two")
  let body = @slide.TextBody::of_paragraphs([p0, p1])
  assert_eq(body.paragraphs.length(), 2)
  assert_eq(body.plain_text(), "one\ntwo")
}

///|
test "AutoShape::with_fill / with_stroke / with_no_fill chain" {
  let s = @slide.AutoShape::rect(
    1,
    "R",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  // rect ships with default fill + stroke; with_no_fill explicitly opts out.
  let bare = s.with_no_fill().with_no_stroke()
  assert_true(bare.fill is Some(_)) // NoFill, not None — explicit
  assert_true(bare.stroke is None)
  // with_fill overrides the default.
  let yellow = @units.RgbColor::new(0xFF, 0xCC, 0x00)
  let painted = s.with_fill(@oxml.SolidFill(@oxml.Color::srgb(yellow)))
  match painted.fill.unwrap() {
    SolidFill(_) => ()
    _ => fail("expected SolidFill")
  }
}

///|
test "AutoShape::with_text_body: attaches styled body" {
  let s = @slide.AutoShape::rect(
    1,
    "Card",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(2_000_000L),
    @units.Emu(500_000L),
  )
  let body = @slide.TextBody::of_styled_text(
    "Header",
    @slide.RunProperties::default().with_font_size(@units.Pt(28.0)).with_bold(),
  )
  let styled = s.with_text_body(body)
  assert_true(styled.text_body is Some(_))
  assert_eq(styled.text_body.unwrap().plain_text(), "Header")
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

///|
test "Picture::with_crop: applies SrcRect with the given percentages" {
  let pic = @slide.Picture::of_image(
    1,
    "Pic",
    "rId99",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  ).with_crop(
    left=@units.Percentage(5.0),
    top=@units.Percentage(10.0),
    right=@units.Percentage(15.0),
    bottom=@units.Percentage(20.0),
  )
  let rect = pic.blip_fill.src_rect.unwrap()
  assert_eq(rect.left, @units.Percentage(5.0))
  assert_eq(rect.top, @units.Percentage(10.0))
  assert_eq(rect.right, @units.Percentage(15.0))
  assert_eq(rect.bottom, @units.Percentage(20.0))
}

///|
test "Picture::with_crop: defaults to 0% on all edges" {
  let pic = @slide.Picture::of_image(
    1,
    "Pic",
    "rId99",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  ).with_crop(left=@units.Percentage(10.0))
  let rect = pic.blip_fill.src_rect.unwrap()
  assert_eq(rect.left, @units.Percentage(10.0))
  assert_eq(rect.top, @units.Percentage(0.0))
  assert_eq(rect.right, @units.Percentage(0.0))
  assert_eq(rect.bottom, @units.Percentage(0.0))
}

///|
test "Picture::with_crop: idempotent — second call replaces, not merges" {
  let pic = @slide.Picture::of_image(
      1,
      "Pic",
      "rId99",
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
    .with_crop(left=@units.Percentage(5.0), right=@units.Percentage(5.0))
    .with_crop(top=@units.Percentage(10.0))
  let rect = pic.blip_fill.src_rect.unwrap()
  // Only `top` survives — the earlier left+right crop was replaced.
  assert_eq(rect.left, @units.Percentage(0.0))
  assert_eq(rect.top, @units.Percentage(10.0))
  assert_eq(rect.right, @units.Percentage(0.0))
  assert_eq(rect.bottom, @units.Percentage(0.0))
}

///|
test "AutoShape::of_preset: carries the chosen preset geometry" {
  let s = @slide.AutoShape::of_preset(
    7,
    "Star",
    @slide.PresetShape::Star5,
    @units.Emu(10L),
    @units.Emu(20L),
    @units.Emu(30L),
    @units.Emu(40L),
  )
  assert_eq(s.id, 7)
  assert_eq(s.name, "Star")
  let xfrm = s.transform.unwrap()
  assert_eq(xfrm.offset.x, @units.Emu(10L))
  assert_eq(xfrm.extent.cy, @units.Emu(40L))
  match s.geometry.unwrap() {
    Preset(p, adj) => {
      assert_true(p == @slide.PresetShape::Star5)
      assert_eq(adj.length(), 0)
    }
    _ => fail("expected Preset geometry")
  }
}

///|
test "AutoShape::with_stroke sets the outline; other fields untouched" {
  let stroke : @oxml.Stroke = {
    width: Some(@units.Emu(12700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0x11, 0x22, 0x33)),
      ),
    ),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  // of_preset (unlike rect/ellipse) starts with no fill/stroke.
  let base = @slide.AutoShape::of_preset(
    1,
    "R",
    @slide.PresetShape::Rect,
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(10L),
    @units.Emu(10L),
  )
  let styled = base.with_stroke(stroke)
  assert_true(styled.stroke == Some(stroke))
  assert_true(base.stroke is None) // immutable builder (ADR-003)
  assert_eq(styled.id, base.id)
}

///|
test "Paragraph::of_styled_text + with_properties" {
  let rp = @slide.RunProperties::default().with_bold()
  let para = @slide.Paragraph::of_styled_text("hi", rp)
  match para.content[0] {
    RunContent(r) => {
      assert_eq(r.text, "hi")
      assert_eq(r.properties.bold.unwrap(), true)
    }
    _ => fail("expected a run")
  }
  // with_properties replaces the paragraph-level properties wholesale.
  let props = { ..@slide.ParagraphProperties::default(), level: 2 }
  let levelled = para.with_properties(props)
  assert_eq(levelled.properties.level, 2)
  assert_eq(para.properties.level, 0) // original unchanged
}
