// Chart XML writer — Phase 7a1.
//
// Inverse of `parser.mbt`: re-emit the captured `<c:chartSpace>` body
// verbatim. As long as Phase 7a1 keeps the body opaque, the writer
// just walks the captured DOM via `@oxml.write_xml_element` — same
// round-trip pattern that `OtherGraphic` uses inside graphic-frame.
//
// Subsequent 7a slices replace the wholesale capture with typed
// emission of the lifted fields, while remaining captured siblings
// continue to ride through `write_xml_element`.

///|
/// Serialise a `Chart` back to `chartN.xml`-shaped bytes.
pub fn Chart::serialize(self : Chart) -> FixedArray[Byte] raise ChartError {
  let xml = serialize_chart_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_chart_xml(chart : Chart) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  // Bind the chart, drawing, and r-side namespaces on the writer up
  // front so children of the chart element can use them without
  // emitting a fresh `xmlns:extN`. The chart namespace is the primary
  // namespace of this part; `a:` is used by `<c:spPr>` shape bodies;
  // `r:` is used by `<c:externalData r:id="…"/>`.
  w.bind_namespace("c", @oxml.chart_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  // The captured `space_body` element already names itself
  // `c:chartSpace` and carries whatever attributes the original had.
  // The chart-specific WriteCtx knows the chart prefix on top of the
  // well-known ones so foreign-namespace children inside the body
  // pick up fresh `extN` prefixes only when truly unknown.
  let ctx = make_chart_ctx()
  w.xml_declaration()
  write_chart_space(w, ctx, chart.space_body)
  w.to_string()
}

///|
/// Walk the captured `<c:chartSpace>` element to the writer, emitting
/// `xmlns:c` / `xmlns:a` / `xmlns:r` declarations directly on the
/// root start tag (so the resulting document is self-contained and
/// matches PowerPoint's emit shape).
fn write_chart_space(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  el : @xml.XmlElement,
) -> Unit raise @xml.XmlError {
  w.start_element(el.name)
  w.namespace_attr("c", @oxml.chart_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  for kv in el.attributes {
    w.attribute(kv.0, kv.1)
  }
  for node in el.children {
    match node {
      Element(c) => @oxml.write_xml_element(w, ctx, c)
      Text(s) => w.text(s)
      CData(s) => w.cdata(s)
    }
  }
  w.end_element()
}

///|
/// Build a write context seeded with the well-known OOXML prefixes
/// plus the chart prefix. The chart namespace isn't included in
/// `WriteCtx::with_well_known_prefixes()` because the rest of the
/// codebase (slide / theme / etc.) doesn't bind it on its writers; we
/// add it here at the chart-writer boundary.
fn make_chart_ctx() -> @oxml.WriteCtx {
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  ctx.known_prefixes[@oxml.chart_ns] = "c"
  ctx
}
