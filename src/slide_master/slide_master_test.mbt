// Slide master parser tests.

///|
let p_ns : String = @oxml.presentation_ns

///|
let r_ns : String = @oxml.office_relationships_ns

///|
fn ascii_bytes(s : String) -> FixedArray[Byte] {
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
fn office_like_master() -> FixedArray[Byte] {
  // A trimmed-down sldMaster: clrMap, sldLayoutIdLst with three layouts,
  // plus a deliberately noisy cSld + txStyles to verify skip behaviour.
  let a_ns = @oxml.drawing_ns
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:cSld>" +
    "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" +
    "<p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/></p:nvGrpSpPr>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "<p:sldLayoutIdLst>" +
    "<p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/>" +
    "<p:sldLayoutId id=\"2147483650\" r:id=\"rId2\"/>" +
    "<p:sldLayoutId id=\"2147483651\" r:id=\"rId3\"/>" +
    "</p:sldLayoutIdLst>" +
    "<p:txStyles>" +
    "<p:titleStyle/><p:bodyStyle/><p:otherStyle/>" +
    "</p:txStyles>" +
    "<p:hf sldNum=\"0\" hdr=\"0\" ftr=\"0\" dt=\"0\"/>" +
    "</p:sldMaster>"
  ascii_bytes(xml)
}

// --- ColorMapping ---

///|
test "parse: clrMap maps every slide-level slot to a theme color" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let cm = m.color_mapping
  assert_true(cm.bg1 is @units.ThemeColor::Lt1)
  assert_true(cm.tx1 is @units.ThemeColor::Dk1)
  assert_true(cm.bg2 is @units.ThemeColor::Lt2)
  assert_true(cm.tx2 is @units.ThemeColor::Dk2)
  assert_true(cm.accent1 is @units.ThemeColor::Accent1)
  assert_true(cm.accent6 is @units.ThemeColor::Accent6)
  assert_true(cm.hlink is @units.ThemeColor::Hlink)
  assert_true(cm.fol_hlink is @units.ThemeColor::FolHlink)
}

///|
test "ColorMapping::resolve looks up slide-level slots" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let cm = m.color_mapping
  // bg1 → lt1 per fixture
  assert_true(
    cm.resolve(@units.ThemeColor::Bg1).unwrap() is @units.ThemeColor::Lt1,
  )
  // accent3 → accent3 (identity)
  assert_true(
    cm.resolve(@units.ThemeColor::Accent3).unwrap()
    is @units.ThemeColor::Accent3,
  )
  // master-level slot is not a mapping key
  assert_true(cm.resolve(@units.ThemeColor::Dk1) is None)
  assert_true(cm.resolve(@units.ThemeColor::PhClr) is None)
}

// --- SlideLayoutRef ---

///|
test "parse: layout id list preserves order and unsigned ids" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  assert_eq(m.layout_refs.length(), 3)
  // OOXML uses xsd:unsignedInt for sldLayoutId/@id; values often exceed
  // 2^31. Verify Int64 storage carries them correctly.
  assert_eq(m.layout_refs[0].id, 2147483649L)
  assert_eq(m.layout_refs[0].r_id, "rId1")
  assert_eq(m.layout_refs[1].id, 2147483650L)
  assert_eq(m.layout_refs[2].id, 2147483651L)
  assert_eq(m.layout_refs[2].r_id, "rId3")
}

// --- skip behaviour ---

///|
test "parse: cSld and txStyles and hf are skipped without error" {
  // The fixture's cSld has nested elements, txStyles has three children,
  // hf has four attributes. None of these are modeled in Phase 3b1.
  // If skip_subtree leaks state, parse() would raise. The fact that the
  // earlier tests pass already demonstrates this — this test asserts it
  // by name so the intent is documented.
  let _ = @slide_master.SlideMaster::parse(office_like_master())
}

// --- error cases ---

///|
test "parse: missing clrMap is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\">" +
    "<p:sldLayoutIdLst/></p:sldMaster>"
  let r = try? @slide_master.SlideMaster::parse(ascii_bytes(xml))
  assert_true(r is Err(@slide_master.SlideMasterError::Malformed(_)))
}

///|
test "parse: clrMap missing required slot is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\">" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\"/>" + // folHlink missing
    "</p:sldMaster>"
  let r = try? @slide_master.SlideMaster::parse(ascii_bytes(xml))
  assert_true(r is Err(@slide_master.SlideMasterError::Malformed(_)))
}

///|
test "parse: clrMap with unknown enum value is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\">" +
    "<p:clrMap bg1=\"weirdo\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "</p:sldMaster>"
  let r = try? @slide_master.SlideMaster::parse(ascii_bytes(xml))
  assert_true(r is Err(@slide_master.SlideMasterError::Malformed(_)))
}

///|
test "parse: sldLayoutId without r:id is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "<p:sldLayoutIdLst><p:sldLayoutId id=\"1\"/></p:sldLayoutIdLst>" +
    "</p:sldMaster>"
  let r = try? @slide_master.SlideMaster::parse(ascii_bytes(xml))
  assert_true(r is Err(@slide_master.SlideMasterError::Malformed(_)))
}

///|
test "parse: malformed XML wraps as XmlFailure" {
  let r = try? @slide_master.SlideMaster::parse(ascii_bytes("<p:sldMaster"))
  assert_true(r is Err(@slide_master.SlideMasterError::XmlFailure(_, _)))
}
