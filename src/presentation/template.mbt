// Blank-deck XML templates.
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
  // `<a:fmtScheme>` (CT_StyleMatrix) — REQUIRED by ECMA-376
  // §20.1.6.10. CT_BaseStyles mandates all three child elements
  // (clrScheme, fontScheme, fmtScheme); without fmtScheme PowerPoint
  // shows a "needs repair" prompt on open. Each style list (fill /
  // line / effect / bgFill) must carry at least three entries; we
  // emit the canonical "subtle / moderate / intense" trio that
  // Microsoft Office's default theme uses — line widths of
  // 6350 / 12700 / 19050 EMU (≈0.5/1/1.5 pt) and placeholder-coloured
  // solid fills (`phClr` resolves to whatever the consumer applies).
  "<a:fmtScheme name=\"Office\">" +
  "<a:fillStyleLst>" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "</a:fillStyleLst>" +
  "<a:lnStyleLst>" +
  "<a:ln w=\"6350\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\">" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:prstDash val=\"solid\"/>" +
  "<a:miter lim=\"800000\"/>" +
  "</a:ln>" +
  "<a:ln w=\"12700\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\">" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:prstDash val=\"solid\"/>" +
  "<a:miter lim=\"800000\"/>" +
  "</a:ln>" +
  "<a:ln w=\"19050\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\">" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:prstDash val=\"solid\"/>" +
  "<a:miter lim=\"800000\"/>" +
  "</a:ln>" +
  "</a:lnStyleLst>" +
  "<a:effectStyleLst>" +
  "<a:effectStyle><a:effectLst/></a:effectStyle>" +
  "<a:effectStyle><a:effectLst/></a:effectStyle>" +
  "<a:effectStyle><a:effectLst/></a:effectStyle>" +
  "</a:effectStyleLst>" +
  "<a:bgFillStyleLst>" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
  "</a:bgFillStyleLst>" +
  "</a:fmtScheme>" +
  "</a:themeElements>" +
  "</a:theme>"

///|
/// Canonical "root group" wrapper inside `<p:spTree>` that PowerPoint
/// Online insists on for every slide / master / layout / notes-master.
/// The empty `<p:grpSpPr/>` variant is spec-valid but triggers the
/// repair banner; the loaded-by-PowerPoint shape always carries a
/// zero-valued `<a:xfrm>`, so we emit one too.
let blank_spTree_root : String = "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm>" +
  "<a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>" +
  "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/>" +
  "</a:xfrm></p:grpSpPr>"

///|
let blank_slide_master_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:sldMaster xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  "<p:cSld>" +
  // PowerPoint expects a background-style reference; the slide master
  // without `<p:bg>` triggers the repair banner.
  "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" +
  "<p:spTree>" +
  blank_spTree_root +
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
  blank_spTree_root +
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

///|
/// `ppt/presProps.xml` — minimal presentation-properties part.
/// Required per ECMA-376 Part 1 §13.3.6. PowerPoint accepts an empty
/// `<p:presentationPr>` element; the Microsoft-extension `<p:extLst>`
/// children Excel emits (discardImageEditData, defaultImageDpi, etc.)
/// are optional and we don't generate them.
let blank_pres_props_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:presentationPr xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"/>"

///|
/// `ppt/viewProps.xml` — minimal view-properties part. Required per
/// ECMA-376 Part 1 §13.3.6. We carry a `<p:gridSpacing>` since that's
/// what PowerPoint's own minimal output looks like.
let blank_view_props_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:viewPr xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:gridSpacing cx=\"76200\" cy=\"76200\"/>" +
  "</p:viewPr>"

///|
/// `ppt/tableStyles.xml` — empty table-styles list with the "no
/// style" default UUID. Required when slides carry tables.
let blank_table_styles_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<a:tblStyleLst xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
  " def=\"{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}\"/>"

///|
/// `docProps/core.xml` — Dublin Core metadata. PowerPoint shows this
/// in the file's Properties dialog. We emit a fixed-but-blank set.
let blank_core_props_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\"" +
  " xmlns:dc=\"http://purl.org/dc/elements/1.1/\"" +
  " xmlns:dcterms=\"http://purl.org/dc/terms/\"" +
  " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">" +
  "<dc:title></dc:title>" +
  "<dc:creator>moon-pptx</dc:creator>" +
  "<cp:lastModifiedBy>moon-pptx</cp:lastModifiedBy>" +
  "<cp:revision>1</cp:revision>" +
  "</cp:coreProperties>"

///|
/// `docProps/app.xml` — extended application properties. Identifies
/// the producing application and provides slide-count metadata used
/// by file-explorer previews.
let blank_app_props_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\"" +
  " xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">" +
  "<Application>moon-pptx</Application>" +
  "<PresentationFormat>On-screen Show (4:3)</PresentationFormat>" +
  "<Slides>0</Slides>" +
  "<Notes>0</Notes>" +
  "<HiddenSlides>0</HiddenSlides>" +
  "<MMClips>0</MMClips>" +
  "<ScaleCrop>false</ScaleCrop>" +
  "<LinksUpToDate>false</LinksUpToDate>" +
  "<SharedDoc>false</SharedDoc>" +
  "<HyperlinksChanged>false</HyperlinksChanged>" +
  "<AppVersion>16.0000</AppVersion>" +
  "</Properties>"

// --- relationships templates ---

///|
let blank_pkg_rels_xml : String = relationships_doc([
  ("rId1", @opc.rt_office_document, "ppt/presentation.xml"),
  ("rId2", @opc.rt_core_properties, "docProps/core.xml"),
  ("rId3", @opc.rt_extended_properties, "docProps/app.xml"),
])

///|
/// Theme is referenced by `slideMaster.xml.rels`; `presentation.xml.rels`
/// only needs the slide-master + the required presProps / viewProps /
/// tableStyles. Slides added by `add_slide_mut` claim rIds from
/// `rId5` onward (next-available after the four fixed entries here)
/// — `add_slide.mbt` walks the existing relationships when picking
/// a new id so this offset is observed automatically.
let blank_presentation_rels_xml : String = relationships_doc([
  ("rId1", @opc.rt_slide_master, "slideMasters/slideMaster1.xml"),
  ("rId2", @opc.rt_pres_props, "presProps.xml"),
  ("rId3", @opc.rt_view_props, "viewProps.xml"),
  ("rId4", @opc.rt_table_styles, "tableStyles.xml"),
])

///|
let blank_slide_master_rels_xml : String = relationships_doc([
  ("rId1", @opc.rt_slide_layout, "../slideLayouts/slideLayout1.xml"),
  ("rId2", @opc.rt_theme, "../theme/theme1.xml"),
])

///|
let blank_slide_layout_rels_xml : String = relationships_doc([
  ("rId1", @opc.rt_slide_master, "../slideMasters/slideMaster1.xml"),
])

///|
/// Build a `.rels` XML document from `(Id, Type, Target)` triples.
/// Inverse of what `@opc.Relationships::parse` consumes; written here
/// (rather than calling `Relationships::serialize`) because we need
/// it at top-level `let`-binding time and the structured builder
/// raises on duplicate ids.
fn relationships_doc(rels : Array[(String, String, String)]) -> String {
  let mut out = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<Relationships xmlns=\"" +
    @opc.relationships_ns +
    "\">"
  for r in rels {
    out = out +
      "<Relationship Id=\"" +
      r.0 +
      "\" Type=\"" +
      r.1 +
      "\" Target=\"" +
      r.2 +
      "\"/>"
  }
  out + "</Relationships>"
}

// --- package builder ---

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
    let part = @opc.Part::new(r.0, @opc.rels_content_type, part_bytes)
    pkg.add_part(part)
  }
  let mut ct = @opc.ContentTypes::new()
    .with_default("rels", @opc.rels_content_type)
    .with_default("xml", "application/xml")
  for p in parts {
    ct = ct.with_override(p.0, p.1)
  }
  pkg.set_content_types(ct)
  pkg.regenerate_content_types_part()
  pkg.to_bytes()
}
