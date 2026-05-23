// Presentation façade tests (Phase 5a).
//
// Builds a minimal-but-valid PPTX inline (smaller scope than the
// `@integration` fixtures since we only need to verify the façade
// dispatches correctly; the per-parser round-trip is covered by each
// sub-package's own tests).

///|
let ns_ct : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
let ns_pkg_rels : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
let ns_a : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
let ns_p : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
let ns_r : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

// --- minimal deck builder ---

///|
/// Build a PPTX byte stream containing one theme + one master + one
/// layout + one slide. Sufficient to verify every Presentation
/// accessor returns the expected count, without the full surface area
/// of `@integration`'s fixtures.
fn minimal_pptx() -> FixedArray[Byte] {
  let entries : Array[(String, FixedArray[Byte])] = [
    ("[Content_Types].xml", @fzip.str_to_u8(content_types_xml())),
    ("_rels/.rels", @fzip.str_to_u8(pkg_rels_xml())),
    ("ppt/presentation.xml", @fzip.str_to_u8(presentation_xml())),
    ("ppt/theme/theme1.xml", @fzip.str_to_u8(theme_xml())),
    ("ppt/slideMasters/slideMaster1.xml", @fzip.str_to_u8(master_xml())),
    ("ppt/slideLayouts/slideLayout1.xml", @fzip.str_to_u8(layout_xml())),
    ("ppt/slides/slide1.xml", @fzip.str_to_u8(slide_xml())),
  ]
  @fzip.zip_sync(entries)
}

///|
fn content_types_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Types xmlns=\"" +
  ns_ct +
  "\">" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"" +
  @oxml.ct_presentation +
  "\"/>" +
  "<Override PartName=\"/ppt/theme/theme1.xml\" ContentType=\"" +
  @oxml.ct_theme +
  "\"/>" +
  "<Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"" +
  @oxml.ct_slide_master +
  "\"/>" +
  "<Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"" +
  @oxml.ct_slide_layout +
  "\"/>" +
  "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"" +
  @oxml.ct_slide +
  "\"/>" +
  "</Types>"
}

///|
fn pkg_rels_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"" +
  ns_pkg_rels +
  "\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>" +
  "</Relationships>"
}

///|
fn presentation_xml() -> String {
  // Stub presentation.xml; we don't parse it via Phase 5a, just keep
  // a well-formed shell so `Package::open` doesn't choke on missing
  // content.
  "<?xml version=\"1.0\"?><p:presentation xmlns:p=\"" + ns_p + "\"/>"
}

///|
fn theme_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<a:theme xmlns:a=\"" +
  ns_a +
  "\" name=\"Office\">" +
  "<a:themeElements>" +
  "<a:clrScheme name=\"Office\">" +
  "<a:dk1><a:sysClr val=\"windowText\" lastClr=\"000000\"/></a:dk1>" +
  "<a:lt1><a:sysClr val=\"window\" lastClr=\"FFFFFF\"/></a:lt1>" +
  "<a:dk2><a:srgbClr val=\"44546A\"/></a:dk2>" +
  "<a:lt2><a:srgbClr val=\"E7E6E6\"/></a:lt2>" +
  "<a:accent1><a:srgbClr val=\"5B9BD5\"/></a:accent1>" +
  "<a:accent2><a:srgbClr val=\"ED7D31\"/></a:accent2>" +
  "<a:accent3><a:srgbClr val=\"A5A5A5\"/></a:accent3>" +
  "<a:accent4><a:srgbClr val=\"FFC000\"/></a:accent4>" +
  "<a:accent5><a:srgbClr val=\"4472C4\"/></a:accent5>" +
  "<a:accent6><a:srgbClr val=\"70AD47\"/></a:accent6>" +
  "<a:hlink><a:srgbClr val=\"0563C1\"/></a:hlink>" +
  "<a:folHlink><a:srgbClr val=\"954F72\"/></a:folHlink>" +
  "</a:clrScheme>" +
  "<a:fontScheme name=\"Office\">" +
  "<a:majorFont><a:latin typeface=\"Calibri Light\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:majorFont>" +
  "<a:minorFont><a:latin typeface=\"Calibri\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:minorFont>" +
  "</a:fontScheme>" +
  "</a:themeElements>" +
  "</a:theme>"
}

///|
fn master_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sldMaster xmlns:p=\"" +
  ns_p +
  "\" xmlns:r=\"" +
  ns_r +
  "\" xmlns:a=\"" +
  ns_a +
  "\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "</p:spTree></p:cSld>" +
  "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
  " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
  " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
  " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
  "<p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst>" +
  "</p:sldMaster>"
}

///|
fn layout_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sldLayout xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\" type=\"title\">" +
  "<p:cSld name=\"Title\"><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "</p:spTree></p:cSld>" +
  "</p:sldLayout>"
}

///|
fn slide_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sld xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\">" +
  "<p:cSld name=\"Slide 1\"><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "</p:spTree></p:cSld>" +
  "</p:sld>"
}

// --- tests ---

///|
test "Presentation::open: succeeds on minimal pptx bytes" {
  let _ = @presentation.Presentation::open(minimal_pptx())
  // No assertion — `open` raising would mark this failed.

}

///|
test "Presentation::open: malformed package raises OpcFailure" {
  let r = try? @presentation.Presentation::open(FixedArray::make(0, b'\x00'))
  assert_true(r is Err(@presentation.PptxError::OpcFailure(_)))
}

///|
test "Presentation accessors return expected counts" {
  let prs = @presentation.Presentation::open(minimal_pptx())
  assert_eq(prs.slides().length(), 1)
  assert_eq(prs.themes().length(), 1)
  assert_eq(prs.slide_masters().length(), 1)
  assert_eq(prs.slide_layouts().length(), 1)
  assert_eq(prs.notes_slides().length(), 0)
  assert_eq(prs.comment_lists().length(), 0)
  assert_true(prs.comment_authors() is None)
}

///|
test "Presentation::slides returns the expected first slide name" {
  let prs = @presentation.Presentation::open(minimal_pptx())
  let s = prs.slides()[0]
  assert_eq(s.name, "Slide 1")
}

///|
test "Presentation::themes returns the expected theme name" {
  let prs = @presentation.Presentation::open(minimal_pptx())
  let t = prs.themes()[0]
  assert_eq(t.name, "Office")
}

///|
test "Presentation::slide_layouts returns title layout" {
  let prs = @presentation.Presentation::open(minimal_pptx())
  let l = prs.slide_layouts()[0]
  assert_eq(l.name, "Title")
  assert_true(l.layout_type is @slide_master.SlideLayoutType::Title)
}

///|
test "Presentation::save: byte round-trip preserves accessor outputs" {
  let prs_in = @presentation.Presentation::open(minimal_pptx())
  let bytes_out = prs_in.save()
  let prs_out = @presentation.Presentation::open(bytes_out)
  // Each accessor's parsed model should compare equal across save /
  // reopen — anything else would mean silent data loss inside the
  // façade.
  assert_eq(prs_in.slides().length(), prs_out.slides().length())
  assert_true(prs_in.slides()[0] == prs_out.slides()[0])
  assert_true(prs_in.themes()[0] == prs_out.themes()[0])
  assert_true(prs_in.slide_masters()[0] == prs_out.slide_masters()[0])
  assert_true(prs_in.slide_layouts()[0] == prs_out.slide_layouts()[0])
}

///|
test "Presentation: notes + comments accessors handle decks that omit them" {
  // The minimal fixture has neither notes nor comments; verify the
  // accessors return empty / None rather than raising.
  let prs = @presentation.Presentation::open(minimal_pptx())
  assert_eq(prs.notes_slides().length(), 0)
  assert_eq(prs.comment_lists().length(), 0)
  assert_true(prs.comment_authors() is None)
}
