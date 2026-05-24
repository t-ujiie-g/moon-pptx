// Shared synthetic-deck fixtures for the end-to-end roundtrip tests.
//
// We don't ship real-world `.pptx` files (license unclear), so this
// file hand-builds three minimal-but-realistic fixtures that exercise
// every read-path parser:
//
//   - `minimal` — 1 theme / 1 master / 1 layout / 1 slide with no shapes.
//     Validates the core OPC + theme + master/layout/slide round-trip.
//   - `rich`    — adds a second slide carrying an auto-shape with text,
//     a picture, a connector, a group, and a `<a:custGeom>` so every
//     shape-tree parser sees content.
//   - `notes_and_comments` — minimal + a notes slide + a commentAuthors
//     part + a commentsN part. Validates speaker notes + comments parsers.
//
// The package builder (`build_pptx`) auto-generates `[Content_Types].xml`
// and `_rels/.rels` from the supplied parts so each fixture only has to
// list the parts it actually carries.

// --- namespaces and content-types ---

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

///|
/// Aliases for the canonical content-type strings exported by
/// `@oxml.content_types`. Test helpers and `parse_everything` use
/// these for dispatch. Keeping them as `let`s here (rather than
/// referencing `@oxml.ct_*` inline) preserves the local short names
/// the original tests were built around.
let ct_presentation : String = @oxml.ct_presentation

///|
let ct_theme : String = @oxml.ct_theme

///|
let ct_slide_master : String = @oxml.ct_slide_master

///|
let ct_slide_layout : String = @oxml.ct_slide_layout

///|
let ct_slide : String = @oxml.ct_slide

///|
let ct_notes_slide : String = @oxml.ct_notes_slide

///|
let ct_comment_authors : String = @oxml.ct_comment_authors

///|
let ct_comments : String = @oxml.ct_comments

// --- fixture pieces ---

///|
/// A complete, parseable Office Theme — 12 colour slots + major/minor
/// fonts. Identical to the canonical Office defaults so we know it
/// reflects what a real .pptx would ship.
fn fixture_theme_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
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
  "<a:fmtScheme name=\"Office\"/>" +
  "</a:themeElements>" +
  "</a:theme>"
}

///|
/// A slide master with the default 1:1 colour mapping and a single
/// layout reference (rId1 → layout1). Exercises the `<p:clrMap>`
/// required attributes plus `<p:sldLayoutIdLst>`.
fn fixture_master_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sldMaster xmlns:p=\"" +
  ns_p +
  "\" xmlns:r=\"" +
  ns_r +
  "\" xmlns:a=\"" +
  ns_a +
  "\">" +
  "<p:cSld>" +
  "<p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "</p:spTree>" +
  "</p:cSld>" +
  "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
  " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
  " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
  " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
  "<p:sldLayoutIdLst>" +
  "<p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/>" +
  "</p:sldLayoutIdLst>" +
  "</p:sldMaster>"
}

///|
/// A single slide layout (type `title`) that inherits the master colour
/// mapping verbatim.
fn fixture_layout_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sldLayout xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\" type=\"title\">" +
  "<p:cSld>" +
  "<p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "</p:spTree>" +
  "</p:cSld>" +
  "</p:sldLayout>"
}

///|
/// A minimal slide carrying one title placeholder so `Slide::parse`
/// has something to extract.
fn fixture_simple_slide_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sld xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\">" +
  "<p:cSld name=\"Slide 1\">" +
  "<p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "<p:sp>" +
  "<p:nvSpPr>" +
  "<p:cNvPr id=\"2\" name=\"Title 1\"/>" +
  "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>" +
  "<p:nvPr><p:ph type=\"ctrTitle\"/></p:nvPr>" +
  "</p:nvSpPr>" +
  "<p:spPr>" +
  "<a:xfrm>" +
  "<a:off x=\"838200\" y=\"365125\"/>" +
  "<a:ext cx=\"10515600\" cy=\"1325563\"/>" +
  "</a:xfrm>" +
  "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
  "</p:spPr>" +
  "<p:txBody>" +
  "<a:bodyPr/><a:lstStyle/>" +
  "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>Hello, MoonBit</a:t></a:r></a:p>" +
  "</p:txBody>" +
  "</p:sp>" +
  "</p:spTree>" +
  "</p:cSld>" +
  "</p:sld>"
}

///|
/// A richer slide: title placeholder + body with formatted text + picture
/// + a custom-geometry shape + a connector. Exercises every shape-tree
/// + text-style + fill/stroke/effect parser.
fn fixture_rich_slide_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sld xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\" xmlns:r=\"" +
  ns_r +
  "\">" +
  "<p:cSld>" +
  "<p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  // AutoShape with text, fill, stroke, and an effect.
  "<p:sp>" +
  "<p:nvSpPr>" +
  "<p:cNvPr id=\"2\" name=\"Body 1\"/>" +
  "<p:cNvSpPr/>" +
  "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr>" +
  "</p:nvSpPr>" +
  "<p:spPr>" +
  "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"500\" cy=\"600\"/></a:xfrm>" +
  "<a:prstGeom prst=\"roundRect\">" +
  "<a:avLst><a:gd name=\"adj\" fmla=\"val 16667\"/></a:avLst>" +
  "</a:prstGeom>" +
  "<a:solidFill><a:srgbClr val=\"5B9BD5\"/></a:solidFill>" +
  "<a:ln w=\"12700\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:ln>" +
  "<a:effectLst>" +
  "<a:outerShdw blurRad=\"50800\" dist=\"38100\" dir=\"5400000\">" +
  "<a:srgbClr val=\"000000\"><a:alpha val=\"35000\"/></a:srgbClr>" +
  "</a:outerShdw>" +
  "</a:effectLst>" +
  "</p:spPr>" +
  "<p:txBody>" +
  "<a:bodyPr/><a:lstStyle/>" +
  "<a:p>" +
  "<a:pPr lvl=\"0\" algn=\"ctr\"/>" +
  "<a:r>" +
  "<a:rPr lang=\"en-US\" sz=\"2400\" b=\"1\" i=\"1\">" +
  "<a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>" +
  "</a:rPr>" +
  "<a:t>Bold italic body text.</a:t>" +
  "</a:r>" +
  "</a:p>" +
  "</p:txBody>" +
  "</p:sp>" +
  // Picture
  "<p:pic>" +
  "<p:nvPicPr>" +
  "<p:cNvPr id=\"3\" name=\"Picture 1\"/>" +
  "<p:cNvPicPr/>" +
  "<p:nvPr/>" +
  "</p:nvPicPr>" +
  "<p:blipFill>" +
  "<a:blip r:embed=\"rId1\"/>" +
  "<a:stretch><a:fillRect/></a:stretch>" +
  "</p:blipFill>" +
  "<p:spPr>" +
  "<a:xfrm><a:off x=\"1000\" y=\"1000\"/><a:ext cx=\"2000\" cy=\"2000\"/></a:xfrm>" +
  "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
  "</p:spPr>" +
  "</p:pic>" +
  // Custom-geometry shape (triangle path)
  "<p:sp>" +
  "<p:nvSpPr>" +
  "<p:cNvPr id=\"4\" name=\"Custom 1\"/>" +
  "<p:cNvSpPr/>" +
  "<p:nvPr/>" +
  "</p:nvSpPr>" +
  "<p:spPr>" +
  "<a:xfrm><a:off x=\"3000\" y=\"3000\"/><a:ext cx=\"1000\" cy=\"1000\"/></a:xfrm>" +
  "<a:custGeom>" +
  "<a:avLst/>" +
  "<a:gdLst/>" +
  "<a:rect l=\"0\" t=\"0\" r=\"1000\" b=\"1000\"/>" +
  "<a:pathLst>" +
  "<a:path w=\"1000\" h=\"1000\">" +
  "<a:moveTo><a:pt x=\"500\" y=\"0\"/></a:moveTo>" +
  "<a:lnTo><a:pt x=\"1000\" y=\"1000\"/></a:lnTo>" +
  "<a:lnTo><a:pt x=\"0\" y=\"1000\"/></a:lnTo>" +
  "<a:close/>" +
  "</a:path>" +
  "</a:pathLst>" +
  "</a:custGeom>" +
  "</p:spPr>" +
  "</p:sp>" +
  // Connector
  "<p:cxnSp>" +
  "<p:nvCxnSpPr>" +
  "<p:cNvPr id=\"5\" name=\"Connector 1\"/>" +
  "<p:cNvCxnSpPr/>" +
  "<p:nvPr/>" +
  "</p:nvCxnSpPr>" +
  "<p:spPr>" +
  "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm>" +
  "<a:prstGeom prst=\"straightConnector1\"><a:avLst/></a:prstGeom>" +
  "</p:spPr>" +
  "</p:cxnSp>" +
  // Group shape with one child
  "<p:grpSp>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"6\" name=\"Group 1\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr>" +
  "<a:xfrm>" +
  "<a:off x=\"5000\" y=\"5000\"/><a:ext cx=\"3000\" cy=\"3000\"/>" +
  "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"3000\" cy=\"3000\"/>" +
  "</a:xfrm>" +
  "</p:grpSpPr>" +
  "<p:sp>" +
  "<p:nvSpPr><p:cNvPr id=\"7\" name=\"Child 1\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
  "<p:spPr>" +
  "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm>" +
  "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom>" +
  "</p:spPr>" +
  "</p:sp>" +
  "</p:grpSp>" +
  "</p:spTree>" +
  "</p:cSld>" +
  "</p:sld>"
}

///|
/// A notes slide with a body placeholder carrying speaker-notes text.
fn fixture_notes_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:notes xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\">" +
  "<p:cSld>" +
  "<p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "<p:sp>" +
  "<p:nvSpPr>" +
  "<p:cNvPr id=\"2\" name=\"Notes Placeholder 1\"/>" +
  "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>" +
  "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr>" +
  "</p:nvSpPr>" +
  "<p:spPr/>" +
  "<p:txBody>" +
  "<a:bodyPr/><a:lstStyle/>" +
  "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>Remember to mention pricing.</a:t></a:r></a:p>" +
  "</p:txBody>" +
  "</p:sp>" +
  "</p:spTree>" +
  "</p:cSld>" +
  "</p:notes>"
}

///|
fn fixture_authors_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:cmAuthorLst xmlns:p=\"" +
  ns_p +
  "\">" +
  "<p:cmAuthor id=\"0\" name=\"Alice\" initials=\"A\" lastIdx=\"1\" clrIdx=\"0\"/>" +
  "<p:cmAuthor id=\"1\" name=\"Bob\" initials=\"B\" lastIdx=\"1\" clrIdx=\"1\"/>" +
  "</p:cmAuthorLst>"
}

///|
fn fixture_comments_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:cmLst xmlns:p=\"" +
  ns_p +
  "\">" +
  "<p:cm authorId=\"0\" dt=\"2026-05-21T12:00:00\" idx=\"1\">" +
  "<p:pos x=\"100\" y=\"200\"/>" +
  "<p:text>Looks great!</p:text>" +
  "</p:cm>" +
  "<p:cm authorId=\"1\" idx=\"1\">" +
  "<p:pos x=\"300\" y=\"400\"/>" +
  "<p:text>Needs a citation.</p:text>" +
  "</p:cm>" +
  "</p:cmLst>"
}

///|
/// Minimal presentation.xml — we never parse this part, but the OPC
/// package rels point at it as the "main document" so we include a
/// well-formed stub for completeness.
fn fixture_presentation_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:presentation xmlns:p=\"" +
  ns_p +
  "\" xmlns:r=\"" +
  ns_r +
  "\"/>"
}

// --- package builder ---

///|
/// Assemble a `.pptx` byte stream from a list of `(part_name, content_type, xml)`
/// tuples. `part_name` uses the OPC convention (leading `/`); the
/// helper also injects `[Content_Types].xml` with the matching
/// `<Override>` entries and `_rels/.rels` pointing to the supplied
/// `main_document_part` (typically `/ppt/presentation.xml`).
///
/// Per-part relationships are *not* generated automatically — the read
/// path doesn't need them yet, since callers walk parts by name and
/// each parser only reads its own part bytes.
fn build_pptx(
  main_document_part : String,
  parts : Array[(String, String, String)],
) -> FixedArray[Byte] {
  let mut ct = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<Types xmlns=\"" +
    ns_ct +
    "\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
  for p in parts {
    ct = ct + "<Override PartName=\"" + p.0 + "\" ContentType=\"" + p.1 + "\"/>"
  }
  ct = ct + "</Types>"
  let pkg_rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<Relationships xmlns=\"" +
    ns_pkg_rels +
    "\">" +
    "<Relationship Id=\"rId1\" Type=\"" +
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" +
    "\" Target=\"" +
    @opc.opc_name_to_zip(main_document_part) +
    "\"/>" +
    "</Relationships>"
  let entries : Array[(String, FixedArray[Byte])] = [
    ("[Content_Types].xml", @fzip.str_to_u8(ct)),
    ("_rels/.rels", @fzip.str_to_u8(pkg_rels)),
  ]
  for p in parts {
    entries.push((@opc.opc_name_to_zip(p.0), @fzip.str_to_u8(p.2)))
  }
  @fzip.zip_sync(entries)
}

// --- the three fixtures ---

///|
/// Minimal valid deck: theme + master + layout + one slide.
fn minimal_deck() -> FixedArray[Byte] {
  build_pptx("/ppt/presentation.xml", [
    ("/ppt/presentation.xml", ct_presentation, fixture_presentation_xml()),
    ("/ppt/theme/theme1.xml", ct_theme, fixture_theme_xml()),
    (
      "/ppt/slideMasters/slideMaster1.xml",
      ct_slide_master,
      fixture_master_xml(),
    ),
    (
      "/ppt/slideLayouts/slideLayout1.xml",
      ct_slide_layout,
      fixture_layout_xml(),
    ),
    ("/ppt/slides/slide1.xml", ct_slide, fixture_simple_slide_xml()),
  ])
}

///|
/// Rich deck: same base parts as the minimal deck plus a second slide
/// that exercises auto-shape with text/fill/stroke/effects, picture,
/// custGeom, connector, and group shape.
fn rich_deck() -> FixedArray[Byte] {
  build_pptx("/ppt/presentation.xml", [
    ("/ppt/presentation.xml", ct_presentation, fixture_presentation_xml()),
    ("/ppt/theme/theme1.xml", ct_theme, fixture_theme_xml()),
    (
      "/ppt/slideMasters/slideMaster1.xml",
      ct_slide_master,
      fixture_master_xml(),
    ),
    (
      "/ppt/slideLayouts/slideLayout1.xml",
      ct_slide_layout,
      fixture_layout_xml(),
    ),
    ("/ppt/slides/slide1.xml", ct_slide, fixture_simple_slide_xml()),
    ("/ppt/slides/slide2.xml", ct_slide, fixture_rich_slide_xml()),
  ])
}

///|
/// Annotated deck: minimal deck plus a notes slide, commentAuthors, and
/// comments parts.
fn notes_and_comments_deck() -> FixedArray[Byte] {
  build_pptx("/ppt/presentation.xml", [
    ("/ppt/presentation.xml", ct_presentation, fixture_presentation_xml()),
    ("/ppt/theme/theme1.xml", ct_theme, fixture_theme_xml()),
    (
      "/ppt/slideMasters/slideMaster1.xml",
      ct_slide_master,
      fixture_master_xml(),
    ),
    (
      "/ppt/slideLayouts/slideLayout1.xml",
      ct_slide_layout,
      fixture_layout_xml(),
    ),
    ("/ppt/slides/slide1.xml", ct_slide, fixture_simple_slide_xml()),
    ("/ppt/notesSlides/notesSlide1.xml", ct_notes_slide, fixture_notes_xml()),
    ("/ppt/commentAuthors.xml", ct_comment_authors, fixture_authors_xml()),
    ("/ppt/comments/comment1.xml", ct_comments, fixture_comments_xml()),
  ])
}
