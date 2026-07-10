// Shared DiagramML constants + helpers.
//
// Single source of truth for the built-in layout / quickStyle / colors
// `uniqueId`s and the per-kind layout identity, so the data writer (the doc
// point's gallery hints) and the static parts (the actual definitions) can't
// drift. Also the one text-run emitter both writers share.

///|
/// Built-in DiagramML `uniqueId` URN prefix for the layout family ids.
let layout_urn_prefix : String = "urn:microsoft.com/office/officeart/2005/8/layout/"

///|
/// `uniqueId` of the built-in "simple" quick style our quickStyle part claims.
let quickstyle_unique_id : String = "urn:microsoft.com/office/officeart/2005/8/quickstyle/simple1"

///|
/// Category of `quickstyle_unique_id`.
let quickstyle_category : String = "simple"

///|
/// `uniqueId` of the built-in accent-1 colour transform our colors part claims.
let colors_unique_id : String = "urn:microsoft.com/office/officeart/2005/8/colors/accent1_2"

///|
/// Category of `colors_unique_id`.
let colors_category : String = "accent1"

///|
/// Language tag stamped on generated runs.
let default_lang : String = "en-US"

///|
/// The built-in layout `uniqueId` + category for `kind`. Consumed by both the
/// data model (the doc point's `loTypeId` / `loCatId` gallery hints) and the
/// layout part (its `uniqueId` + `<dgm:cat>`), so the two never disagree.
fn kind_layout_id(kind : SmartArtKind) -> (String, String) {
  let p = layout_urn_prefix
  match kind {
    List => (p + "list1", "list")
    Process => (p + "process1", "process")
    Cycle => (p + "cycle1", "cycle")
    Pyramid => (p + "pyramid1", "pyramid")
    OrgChart => (p + "orgChart1", "hierarchy")
    Hierarchy => (p + "hierarchy1", "hierarchy")
    Matrix => (p + "matrix1", "matrix")
    Relationship => (p + "radial1", "relationship")
  }
}

///|
/// Emit a text run for `text` inside an already-open `<a:p>` — `<a:r>` with the
/// text when non-empty, or a bare `<a:endParaRPr>` for the empty paragraph.
/// Shared by the data model's `<dgm:t>` and the drawing's `<dsp:txBody>`.
fn write_run_or_endpara(
  w : @xml.XmlWriter,
  text : String,
) -> Unit raise @xml.XmlError {
  if text == "" {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "endParaRPr"))
    w.attribute(@xml.QName::unqualified("lang"), default_lang)
    w.end_element()
  } else {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "r"))
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "rPr"))
    w.attribute(@xml.QName::unqualified("lang"), default_lang)
    w.end_element()
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "t"))
    w.text(text)
    w.end_element()
    w.end_element() // r
  }
}
