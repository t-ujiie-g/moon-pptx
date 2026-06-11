// Static DiagramML parts: layout / colors / quickStyle (roadmap D1).
//
// Unlike the data + drawing parts, these three are independent of the node
// content, so we emit them as template strings (same approach as the blank
// deck in `@presentation`'s `template.mbt`). The cached `<dsp:drawing>`
// renders the diagram; these definitions are consulted when the user *edits*
// the SmartArt in PowerPoint (re-layout / recolour / restyle).
//
// - layout  (`<dgm:layoutDef>`)  : a linear (`lin`) algorithm laying child
//   nodes top-to-bottom (List) or left-to-right (Process), one rounded box per
//   node — the canonical `list1` / `process1` skeleton.
// - colors  (`<dgm:colorsDef>`)  : accent-1 fills with light text.
// - quickStyle (`<dgm:styleDef>`): the "simple" 3-D-free style references.

///|
let xml_decl : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"

///|
/// Per-kind layout metadata: the built-in `uniqueId`, the category type, and
/// the root `<dgm:alg>` element. The flat families differ only in the
/// algorithm (linear top/left vs cycle vs pyramid); the cached `<dsp:drawing>`
/// is what actually renders, so the algorithm matters only on edit-time
/// re-layout.
fn layout_meta(kind : SmartArtKind) -> (String, String, String) {
  let prefix = "urn:microsoft.com/office/officeart/2005/8/layout/"
  let lin = fn(dir) {
    "<dgm:alg type=\"lin\"><dgm:param type=\"linDir\" val=\"" +
    dir +
    "\"/></dgm:alg>"
  }
  match kind {
    List => (prefix + "list1", "list", lin("fromT"))
    Process => (prefix + "process1", "process", lin("fromL"))
    Cycle => (prefix + "cycle1", "cycle", "<dgm:alg type=\"cycle\"/>")
    Pyramid => (prefix + "pyramid1", "pyramid", "<dgm:alg type=\"pyra\"/>")
  }
}

///|
/// `<dgm:layoutDef>` for `kind`.
pub fn SmartArt::layout_xml(self : SmartArt) -> FixedArray[Byte] {
  let (unique_id, category, alg_xml) = layout_meta(self.kind)
  let xml = xml_decl +
    "<dgm:layoutDef xmlns:dgm=\"" +
    @oxml.diagram_ns +
    "\" xmlns:a=\"" +
    @oxml.drawing_ns +
    "\" uniqueId=\"" +
    unique_id +
    "\">" +
    "<dgm:title val=\"\"/><dgm:desc val=\"\"/>" +
    "<dgm:catLst><dgm:cat type=\"" +
    category +
    "\" pri=\"1000\"/></dgm:catLst>" +
    "<dgm:layoutNode name=\"diagram\">" +
    "<dgm:varLst><dgm:dir val=\"norm\"/></dgm:varLst>" +
    alg_xml +
    "<dgm:shape><dgm:adjLst/></dgm:shape>" +
    "<dgm:presOf/><dgm:constrLst/><dgm:ruleLst/>" +
    "<dgm:forEach name=\"nodesForEach\" axis=\"ch\" ptType=\"node\">" +
    "<dgm:layoutNode name=\"node\">" +
    "<dgm:alg type=\"tx\"/>" +
    "<dgm:shape type=\"roundRect\"><dgm:adjLst/></dgm:shape>" +
    "<dgm:presOf axis=\"self\"/>" +
    "<dgm:constrLst>" +
    "<dgm:constr type=\"primFontSz\" val=\"65\"/>" +
    "</dgm:constrLst>" +
    "<dgm:ruleLst><dgm:rule type=\"primFontSz\" val=\"5\" fact=\"NaN\" max=\"NaN\"/></dgm:ruleLst>" +
    "</dgm:layoutNode>" +
    "<dgm:forEach name=\"sibTransForEach\" axis=\"followSib\" ptType=\"sibTrans\" cnt=\"1\">" +
    "<dgm:layoutNode name=\"sibTrans\">" +
    "<dgm:alg type=\"sp\"/><dgm:shape><dgm:adjLst/></dgm:shape>" +
    "<dgm:presOf/><dgm:constrLst/><dgm:ruleLst/>" +
    "</dgm:layoutNode>" +
    "</dgm:forEach>" +
    "</dgm:forEach>" +
    "</dgm:layoutNode>" +
    "</dgm:layoutDef>"
  @oxml.string_to_bytes(xml)
}

///|
/// `<dgm:colorsDef>` — accent-1 fills + light text. Style labels not listed
/// here fall back to PowerPoint's defaults (not a repair trigger).
pub fn SmartArt::colors_xml(self : SmartArt) -> FixedArray[Byte] {
  let _ = self
  let xml = xml_decl +
    "<dgm:colorsDef xmlns:dgm=\"" +
    @oxml.diagram_ns +
    "\" xmlns:a=\"" +
    @oxml.drawing_ns +
    "\" uniqueId=\"urn:microsoft.com/office/officeart/2005/8/colors/accent1_2\">" +
    "<dgm:title val=\"\"/><dgm:desc val=\"\"/>" +
    "<dgm:catLst><dgm:cat type=\"accent1\" pri=\"11200\"/></dgm:catLst>" +
    style_lbl_colors("node0") +
    style_lbl_colors("node1") +
    style_lbl_colors("sibTrans2D1") +
    style_lbl_colors("lnNode1") +
    "</dgm:colorsDef>"
  @oxml.string_to_bytes(xml)
}

///|
/// One `<dgm:styleLbl>` colour block keyed by `name`.
fn style_lbl_colors(name : String) -> String {
  "<dgm:styleLbl name=\"" +
  name +
  "\">" +
  "<dgm:fillClrLst meth=\"repeat\"><a:schemeClr val=\"accent1\"/></dgm:fillClrLst>" +
  "<dgm:linClrLst meth=\"repeat\"><a:schemeClr val=\"lt1\"/></dgm:linClrLst>" +
  "<dgm:effectClrLst meth=\"repeat\"><a:schemeClr val=\"accent1\"/></dgm:effectClrLst>" +
  "<dgm:txLinClrLst meth=\"repeat\"><a:schemeClr val=\"lt1\"/></dgm:txLinClrLst>" +
  "<dgm:txFillClrLst meth=\"repeat\"><a:schemeClr val=\"lt1\"/></dgm:txFillClrLst>" +
  "</dgm:styleLbl>"
}

///|
/// `<dgm:styleDef>` — the "simple" quick style (flat, no 3-D).
pub fn SmartArt::quick_style_xml(self : SmartArt) -> FixedArray[Byte] {
  let _ = self
  let xml = xml_decl +
    "<dgm:styleDef xmlns:dgm=\"" +
    @oxml.diagram_ns +
    "\" xmlns:a=\"" +
    @oxml.drawing_ns +
    "\" uniqueId=\"urn:microsoft.com/office/officeart/2005/8/quickstyle/simple1\">" +
    "<dgm:title val=\"\"/><dgm:desc val=\"\"/>" +
    "<dgm:catLst><dgm:cat type=\"simple\" pri=\"10100\"/></dgm:catLst>" +
    "<dgm:scene3d><a:camera prst=\"orthographicFront\"/><a:lightRig rig=\"flat\" dir=\"t\"/></dgm:scene3d>" +
    style_lbl_style("node0") +
    style_lbl_style("node1") +
    style_lbl_style("lnNode1") +
    "</dgm:styleDef>"
  @oxml.string_to_bytes(xml)
}

///|
/// One `<dgm:styleLbl>` style block keyed by `name`.
fn style_lbl_style(name : String) -> String {
  "<dgm:styleLbl name=\"" +
  name +
  "\">" +
  "<dgm:scene3d><a:camera prst=\"orthographicFront\"/><a:lightRig rig=\"flat\" dir=\"t\"/></dgm:scene3d>" +
  "<dgm:sp3d/>" +
  "<dgm:txPr/>" +
  "<dgm:style>" +
  "<a:lnRef idx=\"2\"><a:scrgbClr r=\"0\" g=\"0\" b=\"0\"/></a:lnRef>" +
  "<a:fillRef idx=\"1\"><a:scrgbClr r=\"0\" g=\"0\" b=\"0\"/></a:fillRef>" +
  "<a:effectRef idx=\"0\"><a:scrgbClr r=\"0\" g=\"0\" b=\"0\"/></a:effectRef>" +
  "<a:fontRef idx=\"minor\"/>" +
  "</dgm:style>" +
  "</dgm:styleLbl>"
}
