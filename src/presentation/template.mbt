// Blank-deck XML templates — Phase 5b2.
//
// `Presentation::new()` builds a minimal PPTX from these constants
// rather than constructing typed model values from scratch. The
// shape-tree captures (`<p:cSld>`, root-group metadata, etc.) ride
// inside the XML literals so the writer's "use captured element if
// present" path emits schema-valid output even though no parse has
// populated the model's extension array.
//
// The strings reference the canonical Office defaults (12-slot
// scheme, Calibri Light / Calibri fonts, screen4x3 / 16x9 sizes) so
// PowerPoint opens the resulting file without prompting to fix the
// theme.

///|
let blank_theme_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"Office\">" +
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
  "<a:majorFont>" +
  "<a:latin typeface=\"Calibri Light\"/>" +
  "<a:ea typeface=\"\"/>" +
  "<a:cs typeface=\"\"/>" +
  "</a:majorFont>" +
  "<a:minorFont>" +
  "<a:latin typeface=\"Calibri\"/>" +
  "<a:ea typeface=\"\"/>" +
  "<a:cs typeface=\"\"/>" +
  "</a:minorFont>" +
  "</a:fontScheme>" +
  "</a:themeElements>" +
  "</a:theme>"

///|
let blank_slide_master_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:sldMaster xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
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

///|
let blank_slide_layout_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:sldLayout xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" type=\"blank\">" +
  "<p:cSld name=\"Blank\"><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "</p:spTree></p:cSld>" +
  "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
  "</p:sldLayout>"

///|
let blank_presentation_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  "<p:sldMasterIdLst>" +
  "<p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/>" +
  "</p:sldMasterIdLst>" +
  "<p:sldIdLst/>" +
  "<p:sldSz cx=\"9144000\" cy=\"6858000\" type=\"screen4x3\"/>" +
  "<p:notesSz cx=\"6858000\" cy=\"9144000\"/>" +
  "</p:presentation>"

// --- relationships templates ---

///|
let blank_pkg_rels_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>" +
  "</Relationships>"

///|
let blank_presentation_rels_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>" +
  "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/>" +
  "</Relationships>"

///|
let blank_slide_master_rels_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>" +
  "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"../theme/theme1.xml\"/>" +
  "</Relationships>"

///|
let blank_slide_layout_rels_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/>" +
  "</Relationships>"

// --- package builder ---

///|
/// Content type for `.rels` files — the OPC packaging relationships
/// namespace. Used as a `Default` extension match so every part-level
/// `.rels` file is routed automatically.
let ct_relationships : String = "application/vnd.openxmlformats-package.relationships+xml"

///|
/// Assemble blank-deck OPC bytes from the list of OOXML parts plus
/// the list of `.rels` parts. The helper:
///
///   1. Adds each OOXML part with its modeled content-type.
///   2. Adds each `.rels` part with the package-relationships
///      content-type.
///   3. Configures `[Content_Types].xml` with the standard
///      `Default` matches for `rels` / `xml` plus an `Override` per
///      OOXML part.
///   4. Regenerates the `[Content_Types].xml` part and serialises
///      the package.
///
/// This is the inverse of the integration-test fixture builder —
/// same structure, different direction.
fn build_blank_package_bytes(
  parts : Array[(String, String, String)],
  rels : Array[(String, String)],
) -> FixedArray[Byte] raise @opc.OpcError {
  let pkg = @opc.Package::new()
  // OOXML parts.
  for p in parts {
    let part_bytes = @oxml.string_to_bytes(p.2)
    let part = @opc.Part::new(p.0, p.1, part_bytes)
    pkg.add_part(part)
  }
  // .rels parts — all share the OPC packaging-relationships content
  // type, picked up via the `Default Extension="rels"` match below.
  for r in rels {
    let part_bytes = @oxml.string_to_bytes(r.1)
    let part = @opc.Part::new(r.0, ct_relationships, part_bytes)
    pkg.add_part(part)
  }
  let mut ct = @opc.ContentTypes::new()
    .with_default("rels", ct_relationships)
    .with_default("xml", "application/xml")
  for p in parts {
    ct = ct.with_override(p.0, p.1)
  }
  pkg.set_content_types(ct)
  pkg.regenerate_content_types_part()
  pkg.to_bytes()
}
