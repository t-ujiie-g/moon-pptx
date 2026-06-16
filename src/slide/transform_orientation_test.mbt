// Tests for shape rotation & flip on `Transform` (roadmap v0.6 F1).
//
// Covers the `<a:xfrm rot/flipH/flipV>` lift: parse, write (with default
// omission), the `Transform` / `AutoShape` / `Picture` / `GroupShape`
// builders, and a graphicFrame `<p:xfrm>` round-trip.

///|
/// Wrap a single `<p:sp>` carrying `xfrm` (the full `<a:xfrm>…</a:xfrm>`
/// string) into a parseable one-slide deck.
fn slide_with_oriented_sp(xfrm : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"R\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr>" +
    xfrm +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
/// An empty spTree to append builder-made shapes onto.
fn empty_sptree_deck() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
test "parse: xfrm rot/flipH/flipV populate Transform" {
  // 5400000 1/60000-deg units = 90°.
  let slide = @slide.Slide::parse(
    slide_with_oriented_sp(
      "<a:xfrm rot=\"5400000\" flipH=\"1\" flipV=\"1\"><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>",
    ),
  )
  match slide.shapes[0] {
    AutoShape(s) => {
      let xfrm = s.transform.unwrap()
      assert_eq(xfrm.rotation.unwrap(), @units.Angle(90.0))
      assert_eq(xfrm.flip_h, true)
      assert_eq(xfrm.flip_v, true)
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: xfrm without orientation defaults to unrotated / un-flipped" {
  let slide = @slide.Slide::parse(
    slide_with_oriented_sp(
      "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm>",
    ),
  )
  match slide.shapes[0] {
    AutoShape(s) => {
      let xfrm = s.transform.unwrap()
      assert_true(xfrm.rotation is None)
      assert_eq(xfrm.flip_h, false)
      assert_eq(xfrm.flip_v, false)
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "Transform::new defaults + with_rotation / with_flip" {
  let t = @slide.Transform::new(
    offset={ x: @units.Emu(0L), y: @units.Emu(0L) },
    extent={ cx: @units.Emu(1L), cy: @units.Emu(1L) },
  )
  assert_true(t.rotation is None)
  assert_eq(t.flip_h, false)
  assert_eq(t.flip_v, false)
  let t2 = t.with_rotation(@units.Angle(30.0)).with_flip(h=true, v=true)
  assert_eq(t2.rotation.unwrap(), @units.Angle(30.0))
  assert_eq(t2.flip_h, true)
  assert_eq(t2.flip_v, true)
  // with_flip() with no args clears both.
  assert_eq(t2.with_flip().flip_h, false)
}

///|
test "AutoShape::with_rotation + with_flip emit attrs and round-trip" {
  let base = @slide.Slide::parse(empty_sptree_deck())
  let rect = @slide.AutoShape::rect(
      2,
      "R",
      @units.Emu(100L),
      @units.Emu(200L),
      @units.Emu(300L),
      @units.Emu(400L),
    )
    .with_rotation(@units.Angle(45.0)) // 45° → 2700000
    .with_flip(h=true)
  let s = base.with_shape(@slide.AutoShape(rect))
  let xml = @oxml.bytes_to_string(s.serialize())
  assert_true(char_index_of(xml, "rot=\"2700000\"") >= 0)
  assert_true(char_index_of(xml, "flipH=\"1\"") >= 0)
  // flipV not set → no attribute emitted.
  assert_true(char_index_of(xml, "flipV") < 0)
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    AutoShape(a) => {
      let xfrm = a.transform.unwrap()
      assert_eq(xfrm.rotation.unwrap(), @units.Angle(45.0))
      assert_eq(xfrm.flip_h, true)
      assert_eq(xfrm.flip_v, false)
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "writer: un-rotated transform emits no rot / flipH / flipV" {
  let base = @slide.Slide::parse(empty_sptree_deck())
  let rect = @slide.AutoShape::rect(
    2,
    "R",
    @units.Emu(100L),
    @units.Emu(200L),
    @units.Emu(300L),
    @units.Emu(400L),
  )
  let s = base.with_shape(@slide.AutoShape(rect))
  let xml = @oxml.bytes_to_string(s.serialize())
  assert_true(char_index_of(xml, "rot=") < 0)
  assert_true(char_index_of(xml, "flipH") < 0)
  assert_true(char_index_of(xml, "flipV") < 0)
}

///|
test "Picture::with_rotation + with_flip round-trip" {
  let base = @slide.Slide::parse(empty_sptree_deck())
  let pic = @slide.Picture::of_image(
      3,
      "Pic",
      "rId2",
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(914400L),
      @units.Emu(914400L),
    )
    .with_rotation(@units.Angle(90.0))
    .with_flip(v=true)
  let s = base.with_shape(@slide.Picture(pic))
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    Picture(p) => {
      let xfrm = p.transform.unwrap()
      assert_eq(xfrm.rotation.unwrap(), @units.Angle(90.0))
      assert_eq(xfrm.flip_h, false)
      assert_eq(xfrm.flip_v, true)
    }
    _ => fail("expected Picture")
  }
}

///|
test "GroupShape::with_rotation + with_flip set the transform" {
  let g : @slide.GroupShape = {
    id: 4,
    name: "G",
    transform: Some(
      @slide.Transform::new(offset={ x: @units.Emu(0L), y: @units.Emu(0L) }, extent={
        cx: @units.Emu(10L),
        cy: @units.Emu(10L),
      }),
    ),
    child_offset: None,
    child_extent: None,
    children: [],
    extension: [],
  }
  let g2 = g.with_rotation(@units.Angle(60.0)).with_flip(h=true)
  let xfrm = g2.transform.unwrap()
  assert_eq(xfrm.rotation.unwrap(), @units.Angle(60.0))
  assert_eq(xfrm.flip_h, true)
  assert_eq(xfrm.flip_v, false)
}

///|
test "GroupShape: rotated group emits orientation and round-trips" {
  // Exercises the group-shape writer path (`write_group_xfrm`), not just
  // the builder — the group `<a:xfrm>` carries rot/flipH.
  let base = @slide.Slide::parse(empty_sptree_deck())
  let g : @slide.GroupShape = {
    id: 5,
    name: "G",
    transform: Some(
      @slide.Transform::new(offset={ x: @units.Emu(0L), y: @units.Emu(0L) }, extent={
        cx: @units.Emu(100L),
        cy: @units.Emu(100L),
      }),
    ),
    child_offset: Some({ x: @units.Emu(0L), y: @units.Emu(0L) }),
    child_extent: Some({ cx: @units.Emu(100L), cy: @units.Emu(100L) }),
    children: [],
    extension: [],
  }
  let s = base.with_shape(
    @slide.Group(g.with_rotation(@units.Angle(90.0)).with_flip(h=true)),
  )
  let xml = @oxml.bytes_to_string(s.serialize())
  assert_true(char_index_of(xml, "rot=\"5400000\"") >= 0)
  assert_true(char_index_of(xml, "flipH=\"1\"") >= 0)
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    Group(rg) => {
      let xfrm = rg.transform.unwrap()
      assert_eq(xfrm.rotation.unwrap(), @units.Angle(90.0))
      assert_eq(xfrm.flip_h, true)
      assert_eq(xfrm.flip_v, false)
    }
    _ => fail("expected GroupShape")
  }
}

///|
test "graphicFrame: <p:xfrm> rot/flip round-trips losslessly" {
  let gf = "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"T\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
    "<p:xfrm rot=\"5400000\" flipH=\"1\">" +
    "<a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/>" +
    "</p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"http://example.com/x\"/></a:graphic>" +
    "</p:graphicFrame>"
  let slide = @slide.Slide::parse(slide_with_shapes_xml(gf))
  match slide.shapes[0] {
    GraphicFrame(f) => {
      let xfrm = f.transform.unwrap()
      assert_eq(xfrm.rotation.unwrap(), @units.Angle(90.0))
      assert_eq(xfrm.flip_h, true)
      assert_eq(xfrm.flip_v, false)
    }
    _ => fail("expected GraphicFrame")
  }
  // Re-serialise → re-parse keeps the orientation.
  let reparsed = @slide.Slide::parse(slide.serialize())
  match reparsed.shapes[0] {
    GraphicFrame(f) => {
      let xfrm = f.transform.unwrap()
      assert_eq(xfrm.rotation.unwrap(), @units.Angle(90.0))
      assert_eq(xfrm.flip_h, true)
    }
    _ => fail("expected GraphicFrame")
  }
}
