// Lossless preservation tests (ADR-004) for the slide master / layout
// parsers. The fixture in slide_master_test.mbt is dense enough to
// drive most assertions: it has <p:cSld>, <p:txStyles>, and <p:hf>
// siblings of the elements we model, all of which should land on
// `SlideMaster.extension`.

///|
test "ADR-004: master captures cSld / txStyles / hf" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let names = []
  for el in m.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("cSld"))
  assert_true(names.contains("txStyles"))
  assert_true(names.contains("hf"))
}

///|
test "ADR-004: master cSld subtree preserves nested shape tree" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let mut cSld : @xml.XmlElement? = None
  for el in m.extension {
    if el.name.local_name == "cSld" {
      cSld = Some(el)
    }
  }
  let c = cSld.unwrap()
  // <p:bg>…</p:bg> + <p:spTree>…</p:spTree>
  assert_eq(c.children.length(), 2)
}

///|
test "ADR-004: master hf attributes round-trip" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let mut hf : @xml.XmlElement? = None
  for el in m.extension {
    if el.name.local_name == "hf" {
      hf = Some(el)
    }
  }
  let h = hf.unwrap()
  assert_eq(h.attributes.length(), 4)
  // First attribute is `sldNum="0"` per the fixture.
  assert_eq(h.attributes[0].0.local_name, "sldNum")
  assert_eq(h.attributes[0].1, "0")
}

// --- SlideLayout.extension ---

///|
test "ADR-004: layout captures cSld + transition + extLst" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    @oxml.drawing_ns +
    "\" type=\"title\">" +
    "<p:cSld name=\"Title\"><p:spTree><p:nvGrpSpPr/></p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "<p:transition><p:fade/></p:transition>" +
    "<p:extLst><p:ext uri=\"{a}\"/></p:extLst>" +
    "</p:sldLayout>"
  let layout = @slide_master.SlideLayout::parse(ascii_bytes(xml))
  assert_eq(layout.name, "Title")
  let names = []
  for el in layout.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("cSld"))
  assert_true(names.contains("transition"))
  assert_true(names.contains("extLst"))
  assert_eq(layout.extension.length(), 3)
}

///|
test "ADR-004: layout cSld preserves both name attribute and shape tree" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<p:cSld name=\"My Layout\"><p:spTree><p:nvGrpSpPr/></p:spTree></p:cSld>" +
    "</p:sldLayout>"
  let layout = @slide_master.SlideLayout::parse(ascii_bytes(xml))
  // The name was pulled out:
  assert_eq(layout.name, "My Layout")
  // …and the full <p:cSld> body is in extension:
  assert_eq(layout.extension.length(), 1)
  let cSld = layout.extension[0]
  assert_eq(cSld.name.local_name, "cSld")
  assert_eq(cSld.attributes[0].0.local_name, "name")
  assert_eq(cSld.attributes[0].1, "My Layout")
  assert_eq(cSld.children.length(), 1)
}
