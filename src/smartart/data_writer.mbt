// DiagramML data-model writer.
//
// Emits `/ppt/diagrams/dataN.xml` — `<dgm:dataModel>` (ECMA-376 §21.4.2.13,
// CT_DataModel): the point list (`<dgm:ptLst>`), connection list
// (`<dgm:cxnLst>`), `<dgm:bg>` / `<dgm:whole>`, and a `<dgm:extLst>` whose
// `<dsp:dataModelExt>` points at the cached drawing part so PowerPoint renders
// the diagram without re-running the layout engine.
//
// Slice 1 lays out the flat top-level node list. Each node becomes a `node`
// point plus a `parTrans` / `sibTrans` transition pair, joined to the root
// `doc` point by a `parOf` connection — the structure PowerPoint itself emits.

///|
/// Generate the `dataN.xml` bytes for this diagram. `drawing_rel_id` is the
/// relationship id (in the data part's own `.rels`) that points at the cached
/// `<dsp:drawing>` — wired by `@presentation.Presentation::add_smartart_mut`.
pub fn SmartArt::data_xml(
  self : SmartArt,
  drawing_rel_id : String,
) -> FixedArray[Byte] raise SmartArtError {
  let xml = self.serialize_data_xml(drawing_rel_id) catch {
    e => raise wrap_xml(e)
  }
  @oxml.string_to_bytes(xml)
}

///|
fn SmartArt::serialize_data_xml(
  self : SmartArt,
  drawing_rel_id : String,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("dgm", @oxml.diagram_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.bind_namespace("dsp", @oxml.diagram_drawing_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "dataModel"))
  w.namespace_attr("dgm", @oxml.diagram_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  w.namespace_attr("dsp", @oxml.diagram_drawing_ns)

  // Flatten the forest: every node (not just top-level) becomes a point, and
  // every node's incoming edge (from its parent, or the doc root) a parOf
  // connection. Flat families are a depth-1 tree → byte-equivalent output.
  let flat = flatten(self.nodes)

  // --- <dgm:ptLst> ---
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "ptLst"))
  write_doc_pt(w, self.kind)
  for f in flat {
    write_node_pt(w, node_id(f.gidx), f.text, f.style)
    write_trans_pt(w, par_trans_id(f.gidx), "parTrans", cxn_id(f.gidx))
    write_trans_pt(w, sib_trans_id(f.gidx), "sibTrans", cxn_id(f.gidx))
  }
  w.end_element() // ptLst

  // --- <dgm:cxnLst> ---
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "cxnLst"))
  for f in flat {
    write_cxn(w, f)
  }
  w.end_element() // cxnLst

  // <dgm:bg/> <dgm:whole/>
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "bg"))
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "whole"))
  w.end_element()

  // --- <dgm:extLst> → <dsp:dataModelExt relId=…> ---
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "extLst"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "ext"))
  w.attribute(@xml.QName::unqualified("uri"), @oxml.diagram_data_model_ext_uri)
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "dataModelExt"))
  w.attribute(@xml.QName::unqualified("relId"), drawing_rel_id)
  w.attribute(@xml.QName::unqualified("minVer"), @oxml.diagram_ns)
  w.end_element() // dataModelExt
  w.end_element() // ext
  w.end_element() // extLst
  w.end_element() // dataModel
  w.to_string()
}

///|
/// The root `<dgm:pt type="doc">` carrying the layout/colors/style gallery
/// hints in `<dgm:prSet>`.
fn write_doc_pt(
  w : @xml.XmlWriter,
  kind : SmartArtKind,
) -> Unit raise @xml.XmlError {
  let (lo_type, lo_cat) = kind_layout_id(kind)
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "pt"))
  w.attribute(@xml.QName::unqualified("modelId"), doc_id)
  w.attribute(@xml.QName::unqualified("type"), "doc")
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "prSet"))
  w.attribute(@xml.QName::unqualified("loTypeId"), lo_type)
  w.attribute(@xml.QName::unqualified("loCatId"), lo_cat)
  w.attribute(@xml.QName::unqualified("qsTypeId"), quickstyle_unique_id)
  w.attribute(@xml.QName::unqualified("qsCatId"), quickstyle_category)
  w.attribute(@xml.QName::unqualified("csTypeId"), colors_unique_id)
  w.attribute(@xml.QName::unqualified("csCatId"), colors_category)
  w.attribute(@xml.QName::unqualified("phldr"), "1")
  w.end_element() // prSet
  write_empty_sppr(w)
  write_pt_text(w, "")
  w.end_element() // pt
}

///|
/// A content `<dgm:pt>` (a node box) carrying `text`, plus its colour
/// overrides. Fill / line overrides live in the point's `<dgm:spPr>`; a text
/// colour goes into the `<dgm:t>` run properties with `custT="1"` on
/// `<dgm:prSet>` so the layout engine keeps it as a manual customisation.
fn write_node_pt(
  w : @xml.XmlWriter,
  model_id : String,
  text : String,
  style : NodeStyle?,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "pt"))
  w.attribute(@xml.QName::unqualified("modelId"), model_id)
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "prSet"))
  w.attribute(@xml.QName::unqualified("phldrT"), text)
  let (fill, line, text_color) = match style {
    Some(s) => (s.fill, s.line, s.text_color)
    None => (None, None, None)
  }
  if text_color is Some(_) {
    w.attribute(@xml.QName::unqualified("custT"), "1")
  }
  w.end_element() // prSet
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "spPr"))
  match fill {
    Some(rgb) => write_srgb_fill(w, rgb)
    None => ()
  }
  match line {
    Some(rgb) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "ln"))
      write_srgb_fill(w, rgb)
      w.end_element()
    }
    None => ()
  }
  w.end_element() // spPr
  write_pt_text(w, text, color?=text_color)
  w.end_element()
}

///|
/// A transition `<dgm:pt type="parTrans"|"sibTrans">` linked to its connection.
fn write_trans_pt(
  w : @xml.XmlWriter,
  model_id : String,
  pt_type : String,
  cxn : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "pt"))
  w.attribute(@xml.QName::unqualified("modelId"), model_id)
  w.attribute(@xml.QName::unqualified("type"), pt_type)
  w.attribute(@xml.QName::unqualified("cxnId"), cxn)
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "prSet"))
  w.end_element()
  write_empty_sppr(w)
  write_pt_text(w, "")
  w.end_element()
}

///|
/// `<dgm:cxn type="parOf">` joining a node to its source — the document root
/// for a top-level node, or its parent node otherwise — carrying the node's
/// parTrans / sibTrans ids.
fn write_cxn(w : @xml.XmlWriter, f : FlatNode) -> Unit raise @xml.XmlError {
  let src_id = match f.parent_gidx {
    None => doc_id
    Some(p) => node_id(p)
  }
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "cxn"))
  w.attribute(@xml.QName::unqualified("modelId"), cxn_id(f.gidx))
  w.attribute(@xml.QName::unqualified("srcId"), src_id)
  w.attribute(@xml.QName::unqualified("destId"), node_id(f.gidx))
  w.attribute(@xml.QName::unqualified("srcOrd"), f.sib_ord.to_string())
  w.attribute(@xml.QName::unqualified("destOrd"), "0")
  w.attribute(@xml.QName::unqualified("parTransId"), par_trans_id(f.gidx))
  w.attribute(@xml.QName::unqualified("sibTransId"), sib_trans_id(f.gidx))
  w.end_element()
}

///|
/// `<dgm:spPr/>` — an empty shape-properties leaf (every point carries one).
fn write_empty_sppr(w : @xml.XmlWriter) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "spPr"))
  w.end_element()
}

///|
/// `<dgm:t>` — a point's text body. Non-empty text emits one run; empty text
/// emits a bare `<a:endParaRPr>` paragraph (the canonical empty body).
/// `color` overrides the run's text colour.
fn write_pt_text(
  w : @xml.XmlWriter,
  text : String,
  color? : @units.RgbColor,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.diagram_ns, "t"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "bodyPr"))
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "lstStyle"))
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "p"))
  write_run_or_endpara(w, text, color?)
  w.end_element() // p
  w.end_element() // t
}
