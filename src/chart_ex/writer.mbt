// Extended-chart XML writer.
//
// Inverse of `parser.mbt`. Re-emits the typed structure in
// schema order:
//
//   <cx:chartSpace>
//     <cx:chartData> (captured) → <cx:chart> →
//     captured extension tail.
//
// Element ordering follows the chartEx schema; series re-emit their
// captured `<cx:series>` body verbatim, including any unmodelled
// children, so the round-trip is lossless.

///|
/// Serialise a `ChartEx` back to `chartExN.xml`-shaped bytes.
pub fn ChartEx::serialize(
  self : ChartEx,
) -> FixedArray[Byte] raise ChartExError {
  let xml = serialize_chart_ex_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_chart_ex_xml(chart : ChartEx) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("cx", @oxml.chart_ex_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  let ctx = make_chart_ex_ctx()
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.chart_ex_ns, "chartSpace"))
  w.namespace_attr("cx", @oxml.chart_ex_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  // <cx:chartData> first (per schema).
  match chart.chart_data {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  // <cx:chart> — REQUIRED.
  write_chart_body(w, ctx, chart.chart)
  // chartSpace-level captured siblings (clrMapOvr / spPr / txPr /
  // externalData / extLst / foreign-ns).
  for ext in chart.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
  w.to_string()
}

///|
fn write_chart_body(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  cb : ChartExBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ex_ns, "chart"))
  match cb.title {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  write_plot_area(w, ctx, cb.plot_area)
  match cb.legend {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in cb.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_plot_area(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  pa : ChartExPlotArea,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ex_ns, "plotArea"))
  write_plot_area_region(w, ctx, pa.plot_area_region)
  for ax in pa.axes {
    @oxml.write_xml_element(w, ctx, ax)
  }
  for ext in pa.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_plot_area_region(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  region : ChartExPlotAreaRegion,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ex_ns, "plotAreaRegion"))
  match region.plot_surface {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for s in region.series {
    // The captured body's name is `<cx:series>` and attributes
    // are already on it — re-emit the captured element verbatim.
    @oxml.write_xml_element(w, ctx, s.body)
  }
  for ext in region.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Build a write context seeded with the well-known OOXML prefixes
/// plus the `cx:` extended-chart prefix.
fn make_chart_ex_ctx() -> @oxml.WriteCtx {
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  ctx.known_prefixes[@oxml.chart_ex_ns] = "cx"
  ctx
}
