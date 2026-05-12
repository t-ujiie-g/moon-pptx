// Slide layout parser tests.

///|
let pl_ns : String = @oxml.presentation_ns

///|
let al_ns : String = @oxml.drawing_ns

///|
fn layout_xml_with_master_mapping() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    pl_ns +
    "\" xmlns:a=\"" +
    al_ns +
    "\" type=\"title\" preserve=\"1\">" +
    "<p:cSld name=\"Title Slide\"><p:spTree/></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "<p:hf sldNum=\"0\" hdr=\"0\" ftr=\"0\" dt=\"0\"/>" +
    "</p:sldLayout>"
  layout_ascii(xml)
}

///|
fn layout_xml_with_override_mapping() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    pl_ns +
    "\" xmlns:a=\"" +
    al_ns +
    "\" type=\"obj\">" +
    "<p:cSld name=\"Object\"><p:spTree/></p:cSld>" +
    "<p:clrMapOvr>" +
    "<a:overrideClrMapping bg1=\"dk1\" tx1=\"lt1\" bg2=\"dk2\" tx2=\"lt2\"" +
    " accent1=\"accent2\" accent2=\"accent3\" accent3=\"accent4\"" +
    " accent4=\"accent5\" accent5=\"accent6\" accent6=\"accent1\"" +
    " hlink=\"folHlink\" folHlink=\"hlink\"/>" +
    "</p:clrMapOvr>" +
    "</p:sldLayout>"
  layout_ascii(xml)
}

///|
fn layout_ascii(s : String) -> FixedArray[Byte] {
  let chars = s.to_array()
  let bytes = FixedArray::make(chars.length(), b'\x00')
  let mut i = 0
  while i < chars.length() {
    bytes[i] = chars[i].to_int().to_byte()
    i = i + 1
  }
  bytes
}

// --- happy path ---

///|
test "parse: layout type and name" {
  let layout = @slide_master.SlideLayout::parse(
    layout_xml_with_master_mapping(),
  )
  assert_true(layout.layout_type is @slide_master.SlideLayoutType::Title)
  assert_eq(layout.name, "Title Slide")
}

///|
test "parse: missing type attribute defaults to Blank" {
  let xml = "<?xml version=\"1.0\"?><p:sldLayout xmlns:p=\"" +
    pl_ns +
    "\"><p:cSld name=\"x\"/></p:sldLayout>"
  let layout = @slide_master.SlideLayout::parse(layout_ascii(xml))
  assert_true(layout.layout_type is @slide_master.SlideLayoutType::Blank)
}

// --- ClrMapOverride ---

///|
test "parse: clrMapOvr with masterClrMapping inherits from master" {
  let layout = @slide_master.SlideLayout::parse(
    layout_xml_with_master_mapping(),
  )
  assert_true(
    layout.clr_map_override is @slide_master.ClrMapOverride::MasterMapping,
  )
}

///|
test "parse: clrMapOvr with overrideClrMapping carries explicit mapping" {
  let layout = @slide_master.SlideLayout::parse(
    layout_xml_with_override_mapping(),
  )
  match layout.clr_map_override {
    Override(cm) => {
      // Verify a couple of distinctive entries from the fixture
      assert_true(cm.bg1 is @units.ThemeColor::Dk1)
      assert_true(cm.accent1 is @units.ThemeColor::Accent2)
      assert_true(cm.hlink is @units.ThemeColor::FolHlink)
    }
    _ => fail("expected Override")
  }
}

///|
test "parse: missing clrMapOvr defaults to MasterMapping" {
  let xml = "<?xml version=\"1.0\"?><p:sldLayout xmlns:p=\"" +
    pl_ns +
    "\" type=\"blank\"><p:cSld name=\"x\"/></p:sldLayout>"
  let layout = @slide_master.SlideLayout::parse(layout_ascii(xml))
  assert_true(
    layout.clr_map_override is @slide_master.ClrMapOverride::MasterMapping,
  )
}

// --- layout type coverage ---

///|
test "parse: layout types map to typed enum (spot check)" {
  let cases = [
    ("title", @slide_master.SlideLayoutType::Title),
    ("blank", @slide_master.SlideLayoutType::Blank),
    ("obj", @slide_master.SlideLayoutType::Object),
    ("twoObj", @slide_master.SlideLayoutType::TwoObj),
    ("titleOnly", @slide_master.SlideLayoutType::TitleOnly),
    (
      "vertTitleAndTxOverChart",
      @slide_master.SlideLayoutType::VertTitleAndTxOverChart,
    ),
  ]
  for c in cases {
    let xml = "<?xml version=\"1.0\"?><p:sldLayout xmlns:p=\"" +
      pl_ns +
      "\" type=\"" +
      c.0 +
      "\"><p:cSld name=\"x\"/></p:sldLayout>"
    let layout = @slide_master.SlideLayout::parse(layout_ascii(xml))
    // SlideLayoutType doesn't impl Show; assert_true on equality so the
    // failure message stays readable.
    assert_true(layout.layout_type == c.1)
  }
}

///|
test "parse: unknown layout type is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldLayout xmlns:p=\"" +
    pl_ns +
    "\" type=\"thisisnotalayout\"><p:cSld name=\"x\"/></p:sldLayout>"
  let r = try? @slide_master.SlideLayout::parse(layout_ascii(xml))
  assert_true(r is Err(@slide_master.SlideMasterError::Malformed(_)))
}

///|
test "parse: malformed override mapping (missing slot) is rejected" {
  // overrideClrMapping is missing folHlink — same enforcement as clrMap
  let xml = "<?xml version=\"1.0\"?><p:sldLayout xmlns:p=\"" +
    pl_ns +
    "\" xmlns:a=\"" +
    al_ns +
    "\" type=\"blank\">" +
    "<p:clrMapOvr><a:overrideClrMapping bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\"" +
    " tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\"/></p:clrMapOvr></p:sldLayout>"
  let r = try? @slide_master.SlideLayout::parse(layout_ascii(xml))
  assert_true(r is Err(@slide_master.SlideMasterError::Malformed(_)))
}
