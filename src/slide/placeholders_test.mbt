// Tests for PlaceholderType + Slide placeholder accessors.

///|
/// A slide whose spTree carries a representative spread of placeholders plus
/// one ordinary drawn shape. Placeholder kinds, in order:
///   ctrTitle · body(idx 1) · ftr · sldNum(idx 10) · content(no type → obj)
/// followed by a plain rectangle with no `<p:ph>` (skipped by accessors).
fn slide_with_placeholders() -> FixedArray[Byte] {
  fn ph_sp(id : Int, name : String, ph : String) -> String {
    "<p:sp><p:nvSpPr>" +
    "<p:cNvPr id=\"" +
    id.to_string() +
    "\" name=\"" +
    name +
    "\"/>" +
    "<p:cNvSpPr/><p:nvPr>" +
    ph +
    "</p:nvPr></p:nvSpPr>" +
    "<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
  }

  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    ph_sp(2, "Title 1", "<p:ph type=\"ctrTitle\"/>") +
    ph_sp(3, "Body 2", "<p:ph type=\"body\" idx=\"1\"/>") +
    ph_sp(4, "Footer 3", "<p:ph type=\"ftr\"/>") +
    ph_sp(5, "Slide Number 4", "<p:ph type=\"sldNum\" idx=\"10\"/>") +
    // No `type` attribute → spec default obj (content placeholder).
    ph_sp(6, "Content 5", "<p:ph idx=\"2\"/>") +
    // Ordinary drawn shape — no <p:ph>, so accessors must skip it.
    "<p:sp><p:nvSpPr><p:cNvPr id=\"7\" name=\"Rect 6\"/><p:cNvSpPr/><p:nvPr/>" +
    "</p:nvSpPr><p:spPr/></p:sp>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
  fixture_bytes(xml)
}

// --- PlaceholderType conversions ---

///|
test "PlaceholderType::from_xml maps known + default + unknown" {
  // PlaceholderType derives (Eq, Debug) but not Show, so compare with == and
  // assert_true (the codebase convention for these typed enums).
  assert_true(@slide.PlaceholderType::from_xml("title") == Title)
  assert_true(@slide.PlaceholderType::from_xml("ctrTitle") == CtrTitle)
  assert_true(@slide.PlaceholderType::from_xml("body") == Body)
  assert_true(@slide.PlaceholderType::from_xml("sldNum") == SldNum)
  assert_true(@slide.PlaceholderType::from_xml("pic") == Pic)
  // Explicit "obj" and an absent attribute both read as Obj.
  assert_true(@slide.PlaceholderType::from_xml("obj") == Obj)
  assert_true(@slide.PlaceholderType::from_xml("") == Obj)
  // Unmodelled value is preserved verbatim.
  assert_true(@slide.PlaceholderType::from_xml("foo") == Other("foo"))
}

///|
test "PlaceholderType::to_xml round-trips every modelled value" {
  let kinds : Array[@slide.PlaceholderType] = [
    Title,
    Body,
    CtrTitle,
    SubTitle,
    Dt,
    SldNum,
    Ftr,
    Hdr,
    Obj,
    Chart,
    Tbl,
    ClipArt,
    Dgm,
    Media,
    SldImg,
    Pic,
  ]
  for k in kinds {
    assert_true(@slide.PlaceholderType::from_xml(k.to_xml()) == k)
  }
  // Other carries its raw string through to_xml.
  assert_eq((Other("custom") : @slide.PlaceholderType).to_xml(), "custom")
}

///|
test "Placeholder::kind reads the raw ph_type" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.shapes[4] {
    AutoShape(s) => {
      let ph = s.placeholder.unwrap()
      assert_eq(ph.ph_type, "") // attribute was absent
      assert_true(ph.kind() == Obj) // …and reads as the spec default
    }
    _ => fail("expected AutoShape at index 4")
  }
}

// --- Slide accessors ---

///|
test "Slide::placeholders lists kinds in source order, skips non-placeholders" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  let kinds = slide.placeholders().map(fn(pair) { pair.0 })
  assert_true(kinds == [CtrTitle, Body, Ftr, SldNum, Obj])
}

///|
test "Slide::title matches ctrTitle" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.title() {
    Some(AutoShape(s)) => assert_eq(s.id, 2)
    _ => fail("expected the ctrTitle placeholder")
  }
}

///|
test "Slide::title also matches a plain title placeholder" {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"9\" name=\"Title\"/><p:cNvSpPr/>" +
    "<p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.title() {
    Some(AutoShape(s)) => assert_eq(s.id, 9)
    _ => fail("expected the title placeholder")
  }
}

///|
test "Slide::body matches body, not content/obj" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.body() {
    Some(AutoShape(s)) => assert_eq(s.id, 3)
    _ => fail("expected the body placeholder")
  }
}

///|
test "Slide::placeholder finds a specific kind by index" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.placeholder(SldNum) {
    Some(AutoShape(s)) => {
      assert_eq(s.id, 5)
      assert_eq(s.placeholder.unwrap().idx, 10)
    }
    _ => fail("expected the slide-number placeholder")
  }
  // The no-type content placeholder is reachable as Obj.
  match slide.placeholder(Obj) {
    Some(AutoShape(s)) => assert_eq(s.id, 6)
    _ => fail("expected the content placeholder via Obj")
  }
}

///|
test "Slide accessors return None when the kind is absent" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  assert_true(slide.placeholder(Chart) is None)
  assert_true(slide.placeholder(SubTitle) is None)
  // A slide with no placeholders at all.
  let bare = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/></p:spTree></p:cSld></p:sld>"
  let empty = @slide.Slide::parse(fixture_bytes(bare))
  assert_eq(empty.placeholders().length(), 0)
  assert_true(empty.title() is None)
  assert_true(empty.body() is None)
}
