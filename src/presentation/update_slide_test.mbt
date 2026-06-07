// Slide replacement tests.

///|
test "update_slide_mut: adding a shape survives save → reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // Get the new (empty) slide.
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 0)
  // Append a rectangle.
  let rect = @slide.AutoShape::rect(
    2,
    "MyRect",
    @units.Emu(100L),
    @units.Emu(200L),
    @units.Emu(300L),
    @units.Emu(400L),
  )
  let modified = slide.with_shape(@slide.AutoShape(rect))
  prs.update_slide_mut(0, modified)
  // After write-back, the in-memory accessor sees the modified slide.
  let slide_after = prs.slides()[0]
  assert_eq(slide_after.shapes.length(), 1)
  // Round-trip through save → reopen.
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  let s = reopened.slides()[0]
  assert_eq(s.shapes.length(), 1)
  match s.shapes[0] {
    AutoShape(a) => {
      assert_eq(a.id, 2)
      assert_eq(a.name, "MyRect")
      let xfrm = a.transform.unwrap()
      assert_eq(xfrm.offset.x, @units.Emu(100L))
      assert_eq(xfrm.extent.cy, @units.Emu(400L))
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "update_slide_mut: textbox round-trips with its text content" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let slide = prs.slides()[0]
  let tb = @slide.AutoShape::textbox(
    2,
    "TB",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914400L),
    @units.Emu(457200L),
    "Hello, MoonBit!",
  )
  prs.update_slide_mut(0, slide.with_shape(@slide.AutoShape(tb)))
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  let s = reopened.slides()[0]
  match s.shapes[0] {
    AutoShape(a) => {
      let body = a.text_body.unwrap()
      assert_eq(body.plain_text(), "Hello, MoonBit!")
    }
    _ => fail("expected AutoShape with textbox")
  }
}

///|
test "update_slide_mut: out-of-range index raises Malformed" {
  let prs = @presentation.Presentation::new()
  // No slides added — index 0 is out of range.
  let blank = @presentation.Presentation::new().slides()
  assert_eq(blank.length(), 0)
  let dummy_xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    "http://schemas.openxmlformats.org/presentationml/2006/main" +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let dummy = @slide.Slide::parse(@fzip.str_to_u8(dummy_xml))
  try prs.update_slide_mut(0, dummy) catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "Presentation::new + add_slide_mut + update_slide_mut: end-to-end builder" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  // Add an ellipse to slide 0 and a textbox to slide 1.
  let s0 = prs.slides()[0]
  let ellipse = @slide.AutoShape::ellipse(
    2,
    "E",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914400L),
    @units.Emu(914400L),
  )
  prs.update_slide_mut(0, s0.with_shape(@slide.AutoShape(ellipse)))
  let s1 = prs.slides()[1]
  let tb = @slide.AutoShape::textbox(
    3,
    "T",
    @units.Emu(100L),
    @units.Emu(100L),
    @units.Emu(914400L),
    @units.Emu(457200L),
    "Slide 2 text",
  )
  prs.update_slide_mut(1, s1.with_shape(@slide.AutoShape(tb)))
  // Save + reopen — both slides should carry their new shapes.
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  let slides = reopened.slides()
  assert_eq(slides.length(), 2)
  assert_eq(slides[0].shapes.length(), 1)
  assert_eq(slides[1].shapes.length(), 1)
  match slides[1].shapes[0] {
    AutoShape(a) => assert_eq(a.text_body.unwrap().plain_text(), "Slide 2 text")
    _ => fail("expected AutoShape textbox on slide 1")
  }
}

// --- pinpoint shape editing (roadmap B4) ---

///|
/// Build a one-slide presentation whose slide holds a rectangle with id 2.
fn prs_with_one_rect() -> @presentation.Presentation raise {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let rect = @slide.AutoShape::rect(
    2,
    "Rect",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(rect)))
  prs
}

///|
test "update_shape_by_id_mut: renames the targeted shape, survives reopen" {
  let prs = prs_with_one_rect()
  prs.update_shape_by_id_mut(0, 2, fn(s) {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Renamed" })
      other => other
    }
  })
  let reopened = @presentation.Presentation::open(prs.save())
  match reopened.slides()[0].shapes[0] {
    AutoShape(a) => assert_eq(a.name, "Renamed")
    _ => fail("expected AutoShape")
  }
}

///|
test "map_slide_shapes_mut: applies to every shape on the slide" {
  let prs = prs_with_one_rect()
  // Append a second shape so we exercise "every".
  let rect2 = @slide.AutoShape::rect(
    3,
    "Rect2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(50L),
    @units.Emu(50L),
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(rect2)))
  prs.map_slide_shapes_mut(0, fn(s) {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "All" })
      other => other
    }
  })
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 2)
  for sh in slide.shapes {
    match sh {
      AutoShape(a) => assert_eq(a.name, "All")
      _ => fail("expected AutoShape")
    }
  }
}

///|
test "update_shape_by_id_mut: raises on missing id or bad slide index" {
  let prs = prs_with_one_rect()
  try prs.update_shape_by_id_mut(0, 999, fn(s) { s }) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
  try prs.map_slide_shapes_mut(99, fn(s) { s }) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}
