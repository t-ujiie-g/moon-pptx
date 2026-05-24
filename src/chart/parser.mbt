// Chart XML reader — Phase 7a1.
//
// Reads a chart part (`/ppt/charts/chartN.xml`) into a `Chart` value.
// Phase 7a1 keeps the entire `<c:chartSpace>` body in `space_body` as
// a captured `@xml.XmlElement` for lossless preservation. Subsequent
// 7a slices lift typed fields out of that element without changing
// the public entry-point.

///|
/// Parse a chart part from raw XML bytes. Root element must be
/// `<c:chartSpace>`.
pub fn Chart::parse(bytes : FixedArray[Byte]) -> Chart raise ChartError {
  parse_chart_xml(bytes_to_string(bytes))
}

///|
fn parse_chart_xml(xml : String) -> Chart raise ChartError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  let (name, attrs) = match event {
    StartElement(n, a) => (n, a)
    _ => raise Malformed("expected <c:chartSpace> root element")
  }
  if name.uri != @oxml.chart_ns || name.local_name != "chartSpace" {
    raise Malformed(
      "expected <c:chartSpace> root but got <" + name.local_name + ">",
    )
  }
  // Capture the entire body verbatim via collect_subtree. Phase 7a2+
  // walk this element and pull typed fields out of it.
  let space_body = @oxml.collect_subtree(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
  { space_body, }
}

// --- shared helpers ---

///|
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise ChartError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise Malformed("unexpected end of input")
  }
}

///|
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise ChartError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
}
