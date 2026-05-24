// Chart XML writer — Phase 7a1 + 7a2.
//
// Phase 7a1 emitted the captured `<c:chartSpace>` body wholesale.
// Phase 7a2 inverts the new typed parser: re-emit the chartSpace
// scalar-leaf children (`<c:date1904>` / `<c:lang>` /
// `<c:roundedCorners>` / `<c:style>`) and the `<c:chart>` typed
// header leaves, then re-emit the captured subtree fields
// (`title`, `plotArea`, `legend`, the 3-D wrappers) verbatim.
// Element ordering follows the ECMA-376 schema — see §21.2.2.29 for
// chartSpace and §21.2.2.6 for chart — so a writer-only round-trip
// produces valid PPTX even when typed fields and captured siblings
// mix.

///|
/// Serialise a `Chart` back to `chartN.xml`-shaped bytes.
pub fn Chart::serialize(self : Chart) -> FixedArray[Byte] raise ChartError {
  let xml = serialize_chart_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_chart_xml(chart : Chart) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("c", @oxml.chart_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  let ctx = make_chart_ctx()
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.chart_ns, "chartSpace"))
  w.namespace_attr("c", @oxml.chart_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  // chartSpace-level scalar leaves come first, in schema order:
  // date1904, lang, roundedCorners, style.
  match chart.date1904 {
    Some(b) => emit_val_bool(w, "date1904", b)
    None => ()
  }
  match chart.lang {
    Some(s) => emit_val_string(w, "lang", s)
    None => ()
  }
  match chart.rounded_corners {
    Some(b) => emit_val_bool(w, "roundedCorners", b)
    None => ()
  }
  match chart.style {
    Some(n) => emit_val_int(w, "style", n)
    None => ()
  }
  // <c:chart> — REQUIRED.
  write_chart_body(w, ctx, chart.chart)
  // Captured chartSpace-level tail (clrMapOvr / spPr / txPr /
  // externalData / printSettings / userShapes / extLst / foreign-ns).
  for ext in chart.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
  w.to_string()
}

///|
/// Emit `<c:chart>` body. Element order follows ECMA-376 §21.2.2.6.
fn write_chart_body(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  cb : ChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "chart"))
  match cb.title {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match cb.auto_title_deleted {
    Some(b) => emit_val_bool(w, "autoTitleDeleted", b)
    None => ()
  }
  match cb.pivot_fmts {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match cb.view3d {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match cb.floor {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match cb.side_wall {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match cb.back_wall {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  @oxml.write_xml_element(w, ctx, cb.plot_area)
  match cb.legend {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match cb.plot_vis_only {
    Some(b) => emit_val_bool(w, "plotVisOnly", b)
    None => ()
  }
  match cb.disp_blanks_as {
    Some(v) => emit_val_string(w, "dispBlanksAs", v.to_xml())
    None => ()
  }
  match cb.show_d_lbls_over_max {
    Some(b) => emit_val_bool(w, "showDLblsOverMax", b)
    None => ()
  }
  for ext in cb.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

// --- val-attribute helpers ---

///|
fn emit_val_bool(
  w : @xml.XmlWriter,
  local_name : String,
  v : Bool,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), if v { "1" } else { "0" })
  w.end_element()
}

///|
fn emit_val_int(
  w : @xml.XmlWriter,
  local_name : String,
  v : Int,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), v.to_string())
  w.end_element()
}

///|
fn emit_val_string(
  w : @xml.XmlWriter,
  local_name : String,
  v : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), v)
  w.end_element()
}

///|
/// Build a write context that knows the chart prefix on top of the
/// well-known OOXML prefixes.
fn make_chart_ctx() -> @oxml.WriteCtx {
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  ctx.known_prefixes[@oxml.chart_ns] = "c"
  ctx
}
