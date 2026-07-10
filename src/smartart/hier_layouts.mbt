// Recursive hierarchy + radial layout definitions.
//
// PowerPoint re-lays-out SmartArt from the `<dgm:layoutDef>` on open (it does
// not honour the cached `<dsp:drawing>` — the 2026-06-16 verification finding,
// ADR-010 status update), so the nesting families need a layout definition
// that actually walks the tree. These templates are minimal simplifications
// of the corresponding built-in Microsoft layouts, structurally verified
// against real Office-emitted `layout1.xml` parts:
//
// - `hier_layout_xml` (OrgChart / Hierarchy) mirrors `orgChart1`'s recursive
//   skeleton: a `hierChild` diagram root, a per-root `hierRoot` composite
//   (text box + a nested `hierChild` stack), a `conn` connector layoutNode
//   selected via `axis="precedSib" ptType="parTrans" st="-1" cnt="1"`, and
//   **recursion via a named `<dgm:forEach>` re-invoked with
//   `<dgm:forEach ref="…"/>`** — the piece the old single-level template
//   lacked (it drew only the top level). The assistant / hang-branch
//   machinery of the real orgChart1 is omitted (our builder never creates
//   `asst` points or sets `hierBranch`).
// - `radial_layout_xml` (Relationship) mirrors `radial1`: a `cycle` algorithm
//   with `ctrShpMap="fNode"` pinning the first node (the hub) at the centre,
//   one ellipse per spoke, and a `conn` line per hub→spoke `parTrans`.

///|
/// The repeated text-box layoutNode of the hierarchy layout — `name` must be
/// unique per definition; `style_lbl` colours the top-level roots (`node0`)
/// differently from deeper nodes (`node1`). Always named explicitly:
/// PowerPoint Web renders an absent styleLbl as black boxes.
fn hier_text_node(name : String, style_lbl : String) -> String {
  "<dgm:layoutNode name=\"" +
  name +
  "\" styleLbl=\"" +
  style_lbl +
  "\">" +
  "<dgm:alg type=\"tx\"/>" +
  "<dgm:shape type=\"roundRect\"><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf axis=\"self\" ptType=\"node\" cnt=\"1\"/>" +
  "<dgm:constrLst>" +
  "<dgm:constr type=\"primFontSz\" val=\"65\"/>" +
  font_margin_constrs +
  "</dgm:constrLst>" +
  font_shrink_rule_lst +
  "</dgm:layoutNode>"
}

///|
/// Text margins proportional to the font size — the four `?Marg`
/// constraints every text layoutNode carries (shared by the hierarchy
/// boxes and the radial ellipses).
let font_margin_constrs : String = "<dgm:constr type=\"lMarg\" refType=\"primFontSz\" fact=\"0.05\"/>" +
  "<dgm:constr type=\"rMarg\" refType=\"primFontSz\" fact=\"0.05\"/>" +
  "<dgm:constr type=\"tMarg\" refType=\"primFontSz\" fact=\"0.05\"/>" +
  "<dgm:constr type=\"bMarg\" refType=\"primFontSz\" fact=\"0.05\"/>"

///|
/// The standard "font may shrink to 5 pt" rule list on text layoutNodes.
let font_shrink_rule_lst : String = "<dgm:ruleLst><dgm:rule type=\"primFontSz\" val=\"5\" fact=\"NaN\" max=\"NaN\"/></dgm:ruleLst>"

///|
/// The parent→child connector layoutNode (`alg type="conn"`), selected by the
/// caller's `precedSib parTrans` forEach. Bent 1-D connector from the parent
/// box's bottom centre to the child box's top centre, drawn under the boxes.
let hier_conn_node : String = "<dgm:layoutNode name=\"childConn\">" +
  "<dgm:alg type=\"conn\">" +
  "<dgm:param type=\"connRout\" val=\"bend\"/>" +
  "<dgm:param type=\"dim\" val=\"1D\"/>" +
  "<dgm:param type=\"endSty\" val=\"noArr\"/>" +
  "<dgm:param type=\"begPts\" val=\"bCtr\"/>" +
  "<dgm:param type=\"endPts\" val=\"tCtr\"/>" +
  "<dgm:param type=\"bendPt\" val=\"end\"/>" +
  "</dgm:alg>" +
  "<dgm:shape type=\"conn\" zOrderOff=\"-99999\"><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf axis=\"self\"/>" +
  "<dgm:constrLst><dgm:constr type=\"begPad\"/><dgm:constr type=\"endPad\"/></dgm:constrLst>" +
  "<dgm:ruleLst/>" +
  "</dgm:layoutNode>"

///|
/// `<dgm:layoutDef>` for the recursive tree families (`OrgChart` /
/// `Hierarchy`). The two differ only in identity (uniqueId / category) and
/// the `<dgm:orgChart val="1"/>` variable that enables org-chart-specific UI.
fn hier_layout_xml(kind : SmartArtKind) -> String {
  let (unique_id, category) = kind_layout_id(kind)
  let org_var = match kind {
    OrgChart => "<dgm:orgChart val=\"1\"/>"
    _ => ""
  }
  xml_decl +
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
  "<dgm:varLst>" +
  org_var +
  "<dgm:chPref val=\"1\"/><dgm:dir val=\"norm\"/><dgm:animLvl val=\"lvl\"/><dgm:resizeHandles val=\"exact\"/>" +
  "</dgm:varLst>" +
  "<dgm:alg type=\"hierChild\"><dgm:param type=\"linDir\" val=\"fromL\"/></dgm:alg>" +
  "<dgm:shape><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf/>" +
  // Ideal box sizes (scaled to fit by the hier algorithms), uniform font,
  // and the root↔child / sibling spacing — the same constraint set the
  // built-in orgChart1 places on its diagram root.
  "<dgm:constrLst>" +
  "<dgm:constr type=\"w\" for=\"des\" forName=\"rootNode\" refType=\"w\" fact=\"10\"/>" +
  "<dgm:constr type=\"h\" for=\"des\" forName=\"rootNode\" refType=\"w\" refFor=\"des\" refForName=\"rootNode\" fact=\"0.5\"/>" +
  "<dgm:constr type=\"w\" for=\"des\" forName=\"childNode\" refType=\"w\" fact=\"10\"/>" +
  "<dgm:constr type=\"h\" for=\"des\" forName=\"childNode\" refType=\"w\" refFor=\"des\" refForName=\"rootNode\" fact=\"0.5\"/>" +
  "<dgm:constr type=\"primFontSz\" for=\"des\" ptType=\"node\" op=\"equ\"/>" +
  "<dgm:constr type=\"sp\" for=\"des\" op=\"equ\"/>" +
  "<dgm:constr type=\"sp\" for=\"des\" forName=\"rootHier\" refType=\"w\" refFor=\"des\" refForName=\"rootNode\" fact=\"0.21\"/>" +
  "<dgm:constr type=\"sp\" for=\"des\" forName=\"childHier\" refType=\"sp\" refFor=\"des\" refForName=\"rootHier\"/>" +
  "<dgm:constr type=\"sibSp\" refType=\"w\" refFor=\"des\" refForName=\"rootNode\" fact=\"0.21\"/>" +
  "<dgm:constr type=\"sibSp\" for=\"des\" forName=\"rootStack\" refType=\"sibSp\"/>" +
  "<dgm:constr type=\"sibSp\" for=\"des\" forName=\"childStack\" refType=\"sibSp\"/>" +
  "<dgm:constr type=\"secSibSp\" refType=\"w\" refFor=\"des\" refForName=\"rootNode\" fact=\"0.21\"/>" +
  "<dgm:constr type=\"secSibSp\" for=\"des\" forName=\"rootStack\" refType=\"secSibSp\"/>" +
  "<dgm:constr type=\"secSibSp\" for=\"des\" forName=\"childStack\" refType=\"secSibSp\"/>" +
  "</dgm:constrLst>" +
  "<dgm:ruleLst/>" +
  // One hierRoot per top-level node (OrgChart has one; Hierarchy may have a
  // forest).
  "<dgm:forEach name=\"rootForEach\" axis=\"ch\" ptType=\"node\">" +
  "<dgm:layoutNode name=\"rootHier\">" +
  "<dgm:alg type=\"hierRoot\"/>" +
  "<dgm:shape><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf/>" +
  "<dgm:constrLst><dgm:constr type=\"bendDist\" for=\"des\" ptType=\"parTrans\" refType=\"sp\" fact=\"0.5\"/></dgm:constrLst>" +
  "<dgm:ruleLst/>" +
  hier_text_node("rootNode", "node0") +
  "<dgm:layoutNode name=\"rootStack\">" +
  "<dgm:alg type=\"hierChild\"/>" +
  "<dgm:shape><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf/>" +
  "<dgm:constrLst/><dgm:ruleLst/>" +
  // The recursive unit: for each child node emit its incoming connector
  // (the parTrans point immediately preceding it) + its own hierRoot, whose
  // inner stack re-invokes this very forEach by name — full-depth layout.
  "<dgm:forEach name=\"childForEach\" axis=\"ch\" ptType=\"node\">" +
  "<dgm:forEach name=\"connForEach\" axis=\"precedSib\" ptType=\"parTrans\" st=\"-1\" cnt=\"1\">" +
  hier_conn_node +
  "</dgm:forEach>" +
  "<dgm:layoutNode name=\"childHier\">" +
  "<dgm:alg type=\"hierRoot\"/>" +
  "<dgm:shape><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf/>" +
  "<dgm:constrLst><dgm:constr type=\"bendDist\" for=\"des\" ptType=\"parTrans\" refType=\"sp\" fact=\"0.5\"/></dgm:constrLst>" +
  "<dgm:ruleLst/>" +
  // PowerPoint Web resolves an *absent* styleLbl to black boxes rather
  // than a usable default, so child nodes name `node1` explicitly (the
  // accent-1 label our colors/quickStyle parts define). Verified against
  // a real render: only the node0-labelled roots drew coloured without it.
  hier_text_node("childNode", "node1") +
  "<dgm:layoutNode name=\"childStack\">" +
  "<dgm:alg type=\"hierChild\"/>" +
  "<dgm:shape><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf/>" +
  "<dgm:constrLst/><dgm:ruleLst/>" +
  "<dgm:forEach name=\"recurseForEach\" ref=\"childForEach\"/>" +
  "</dgm:layoutNode>" +
  "</dgm:layoutNode>" +
  "</dgm:forEach>" +
  "</dgm:layoutNode>" +
  "</dgm:layoutNode>" +
  "</dgm:forEach>" +
  "</dgm:layoutNode>" +
  "</dgm:layoutDef>"
}

///|
/// `<dgm:layoutDef>` for `Relationship` — the built-in `radial1` skeleton:
/// a `cycle` algorithm with `ctrShpMap="fNode"` pins the first child (the
/// hub) at the centre and rings the remaining descendants (the spokes),
/// with a `conn` line per hub→spoke `parTrans`.
fn radial_layout_xml() -> String {
  let (unique_id, category) = kind_layout_id(Relationship)
  xml_decl +
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
  "<dgm:varLst><dgm:chPref val=\"1\"/><dgm:dir val=\"norm\"/><dgm:resizeHandles val=\"exact\"/></dgm:varLst>" +
  "<dgm:alg type=\"cycle\">" +
  "<dgm:param type=\"stAng\" val=\"0\"/><dgm:param type=\"spanAng\" val=\"360\"/><dgm:param type=\"ctrShpMap\" val=\"fNode\"/>" +
  "</dgm:alg>" +
  "<dgm:shape><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf/>" +
  "<dgm:constrLst>" +
  "<dgm:constr type=\"w\" for=\"ch\" forName=\"hubNode\" refType=\"w\"/>" +
  "<dgm:constr type=\"w\" for=\"ch\" forName=\"spokeNode\" refType=\"w\" refFor=\"ch\" refForName=\"hubNode\" op=\"equ\"/>" +
  "<dgm:constr type=\"sp\" refType=\"w\" refFor=\"ch\" refForName=\"spokeNode\" fact=\"0.3\"/>" +
  "<dgm:constr type=\"sibSp\" refType=\"w\" refFor=\"ch\" refForName=\"spokeNode\" fact=\"0.3\"/>" +
  "<dgm:constr type=\"primFontSz\" for=\"ch\" forName=\"hubNode\" val=\"65\"/>" +
  "<dgm:constr type=\"primFontSz\" for=\"des\" forName=\"spokeNode\" op=\"equ\" val=\"65\"/>" +
  "</dgm:constrLst>" +
  "<dgm:ruleLst/>" +
  // The hub: the document's first (and, from our builder, only) child node.
  "<dgm:forEach name=\"hubForEach\" axis=\"ch\" ptType=\"node\" cnt=\"1\">" +
  radial_shape_node("hubNode", "node0") +
  // The spokes: every child *point* of the hub — the parTrans points become
  // connector lines, the node points become the ringed ellipses.
  "<dgm:forEach name=\"spokesForEach\" axis=\"ch\">" +
  "<dgm:forEach name=\"spokeConnForEach\" axis=\"self\" ptType=\"parTrans\">" +
  "<dgm:layoutNode name=\"spokeConn\">" +
  "<dgm:alg type=\"conn\">" +
  "<dgm:param type=\"dim\" val=\"1D\"/>" +
  "<dgm:param type=\"begPts\" val=\"auto\"/><dgm:param type=\"endPts\" val=\"auto\"/>" +
  "<dgm:param type=\"begSty\" val=\"noArr\"/><dgm:param type=\"endSty\" val=\"noArr\"/>" +
  "</dgm:alg>" +
  "<dgm:shape type=\"conn\"><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf axis=\"self\"/>" +
  "<dgm:constrLst>" +
  "<dgm:constr type=\"connDist\"/>" +
  "<dgm:constr type=\"w\" val=\"1\"/><dgm:constr type=\"h\" val=\"5\"/>" +
  "<dgm:constr type=\"begPad\"/><dgm:constr type=\"endPad\"/>" +
  "</dgm:constrLst>" +
  "<dgm:ruleLst/>" +
  "</dgm:layoutNode>" +
  "</dgm:forEach>" +
  "<dgm:forEach name=\"spokeNodeForEach\" axis=\"self\" ptType=\"node\">" +
  radial_shape_node("spokeNode", "node1") +
  "</dgm:forEach>" +
  "</dgm:forEach>" +
  "</dgm:forEach>" +
  "</dgm:layoutNode>" +
  "</dgm:layoutDef>"
}

///|
/// An ellipse text node of the radial layout (the hub or a spoke).
fn radial_shape_node(name : String, style_lbl : String) -> String {
  "<dgm:layoutNode name=\"" +
  name +
  "\" styleLbl=\"" +
  style_lbl +
  "\">" +
  "<dgm:alg type=\"tx\"/>" +
  "<dgm:shape type=\"ellipse\"><dgm:adjLst/></dgm:shape>" +
  "<dgm:presOf axis=\"self\" ptType=\"node\" cnt=\"1\"/>" +
  "<dgm:constrLst>" +
  "<dgm:constr type=\"h\" refType=\"w\"/>" +
  font_margin_constrs +
  "</dgm:constrLst>" +
  font_shrink_rule_lst +
  "</dgm:layoutNode>"
}
