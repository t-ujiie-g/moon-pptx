// Slide master / slide layout writer round-trip tests.

///|
let a_ns : String = @oxml.drawing_ns

///|
fn roundtrip_master(
  bytes : FixedArray[Byte],
) -> @slide_master.SlideMaster raise {
  let first = @slide_master.SlideMaster::parse(bytes)
  @slide_master.SlideMaster::parse(first.serialize())
}

///|
fn roundtrip_layout(
  bytes : FixedArray[Byte],
) -> @slide_master.SlideLayout raise {
  let first = @slide_master.SlideLayout::parse(bytes)
  @slide_master.SlideLayout::parse(first.serialize())
}

// --- SlideMaster ---

///|
fn master_xml_with_default_clr_map() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "<p:sldLayoutIdLst>" +
    "<p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/>" +
    "<p:sldLayoutId id=\"2147483650\" r:id=\"rId2\"/>" +
    "</p:sldLayoutIdLst>" +
    "<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>" +
    "<p:hf sldNum=\"0\" hdr=\"0\" ftr=\"0\" dt=\"0\"/>" +
    "</p:sldMaster>"
  ascii_bytes(xml)
}

///|
test "SlideMaster::serialize: round-trips a default-clrMap master" {
  let m0 = @slide_master.SlideMaster::parse(master_xml_with_default_clr_map())
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  assert_true(m0 == m1)
}

///|
test "SlideMaster::serialize: preserves layout refs in source order" {
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  assert_eq(m1.layout_refs.length(), 2)
  assert_eq(m1.layout_refs[0].id, 2147483649L)
  assert_eq(m1.layout_refs[0].r_id, "rId1")
  assert_eq(m1.layout_refs[1].r_id, "rId2")
}

///|
test "SlideMaster::serialize: preserves the 12-slot color mapping" {
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  assert_true(m1.color_mapping.bg1 == @units.ThemeColor::Lt1)
  assert_true(m1.color_mapping.tx1 == @units.ThemeColor::Dk1)
  assert_true(m1.color_mapping.accent6 == @units.ThemeColor::Accent6)
  assert_true(m1.color_mapping.fol_hlink == @units.ThemeColor::FolHlink)
}

///|
test "SlideMaster::serialize: preserves cSld + txStyles + hf via extension" {
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  let names = m1.extension.map(fn(e) { e.name.local_name })
  assert_true(names.contains("cSld"))
  assert_true(names.contains("txStyles"))
  assert_true(names.contains("hf"))
}

///|
test "SlideMaster::serialize: non-default clrMap (bg1=dk1) round-trips" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:clrMap bg1=\"dk1\" tx1=\"lt1\" bg2=\"dk2\" tx2=\"lt2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "</p:sldMaster>"
  let m0 = @slide_master.SlideMaster::parse(ascii_bytes(xml))
  let m1 = roundtrip_master(ascii_bytes(xml))
  assert_true(m0 == m1)
  assert_true(m1.color_mapping.bg1 == @units.ThemeColor::Dk1)
}

// --- SlideLayout ---

///|
fn layout_xml_title() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\" type=\"title\">" +
    "<p:cSld name=\"Title Slide\"><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "</p:sldLayout>"
  ascii_bytes(xml)
}

///|
test "SlideLayout::serialize: round-trips a title layout" {
  let l0 = @slide_master.SlideLayout::parse(layout_xml_title())
  let l1 = roundtrip_layout(layout_xml_title())
  assert_true(l0 == l1)
}

///|
test "SlideLayout::serialize: preserves name and type" {
  let l1 = roundtrip_layout(layout_xml_title())
  assert_eq(l1.name, "Title Slide")
  assert_true(l1.layout_type == @slide_master.SlideLayoutType::Title)
}

///|
test "SlideLayout::serialize: Blank layout (absent type attr) round-trips" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "</p:sldLayout>"
  let l0 = @slide_master.SlideLayout::parse(ascii_bytes(xml))
  let l1 = roundtrip_layout(ascii_bytes(xml))
  assert_true(l0 == l1)
  assert_true(l1.layout_type == @slide_master.SlideLayoutType::Blank)
}

///|
test "SlideLayout::serialize: overrideClrMapping with custom slots" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\" type=\"obj\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:overrideClrMapping" +
    " bg1=\"dk1\" tx1=\"lt1\" bg2=\"dk2\" tx2=\"lt2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/></p:clrMapOvr>" +
    "</p:sldLayout>"
  let l0 = @slide_master.SlideLayout::parse(ascii_bytes(xml))
  let l1 = roundtrip_layout(ascii_bytes(xml))
  assert_true(l0 == l1)
  match l1.clr_map_override {
    Override(cm) => assert_true(cm.bg1 == @units.ThemeColor::Dk1)
    _ => fail("expected Override")
  }
}

///|
test "SlideLayoutType: round-trip every variant via to_xml -> from_xml" {
  let cases = [
    @slide_master.SlideLayoutType::Title,
    @slide_master.SlideLayoutType::Tx,
    @slide_master.SlideLayoutType::Blank,
    @slide_master.SlideLayoutType::Object,
    @slide_master.SlideLayoutType::TitleOnly,
    @slide_master.SlideLayoutType::Custom,
    @slide_master.SlideLayoutType::PicTx,
    @slide_master.SlideLayoutType::VertTitleAndTxOverChart,
  ]
  for c in cases {
    let xml = c.to_xml()
    let parsed = @slide_master.SlideLayoutType::from_xml(xml)
    assert_true(parsed == c)
  }
}
