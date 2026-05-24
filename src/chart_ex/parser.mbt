// Extended-chart XML reader.
//
// Walks `<cx:chartSpace>` → `<cx:chart>` → `<cx:plotArea>` →
// `<cx:plotAreaRegion>` → `<cx:series>`. Each `<cx:series>` carries
// the `layoutId` attribute that discriminates the chart kind
// (waterfall / treemap / sunburst / histogram / boxWhisker / funnel /
// paretoLine / regionMap / clusteredColumn — plus Other(…) for any
// future Microsoft extension).
//
// Series body contents (`<cx:tx>`, `<cx:dataLabels>`, `<cx:dataPt>`,
// `<cx:dataId>`, `<cx:layoutPr>`, …) stay as captured `XmlElement`
// payloads for round-trip preservation; their typed AST is a later
// slice.

///|
/// Parse an extended-chart part from raw XML bytes. Root element
/// must be `<cx:chartSpace>`.
pub fn ChartEx::parse(bytes : FixedArray[Byte]) -> ChartEx raise ChartExError {
  parse_chart_ex_xml(bytes_to_string(bytes))
}

///|
fn parse_chart_ex_xml(xml : String) -> ChartEx raise ChartExError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  let name = match event {
    StartElement(n, _) => n
    _ => raise Malformed("expected <cx:chartSpace> root element")
  }
  if name.uri != @oxml.chart_ex_ns || name.local_name != "chartSpace" {
    raise Malformed(
      "expected <cx:chartSpace> root but got <" + name.local_name + ">",
    )
  }
  parse_chart_space(r)
}

///|
fn parse_chart_space(r : @xml.XmlReader) -> ChartEx raise ChartExError {
  let mut chart_data : @xml.XmlElement? = None
  let mut chart_body : ChartExBody? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ex_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "chartData" =>
              chart_data = Some(collect_subtree_unknown(r, child, attrs))
            "chart" => chart_body = Some(parse_chart_body(r))
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let chart = match chart_body {
    Some(c) => c
    None => raise Malformed("<cx:chartSpace> is missing required <cx:chart>")
  }
  { chart_data, chart, extension }
}

///|
fn parse_chart_body(r : @xml.XmlReader) -> ChartExBody raise ChartExError {
  let mut title : @xml.XmlElement? = None
  let mut plot_area : ChartExPlotArea? = None
  let mut legend : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ex_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "title" => title = Some(collect_subtree_unknown(r, child, attrs))
            "plotArea" => plot_area = Some(parse_plot_area(r))
            "legend" => legend = Some(collect_subtree_unknown(r, child, attrs))
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let pa = match plot_area {
    Some(p) => p
    None => raise Malformed("<cx:chart> is missing required <cx:plotArea>")
  }
  { title, plot_area: pa, legend, extension }
}

///|
fn parse_plot_area(r : @xml.XmlReader) -> ChartExPlotArea raise ChartExError {
  let mut plot_area_region : ChartExPlotAreaRegion? = None
  let axes : Array[@xml.XmlElement] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ex_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "plotAreaRegion" =>
              plot_area_region = Some(parse_plot_area_region(r))
            "axis" => axes.push(collect_subtree_unknown(r, child, attrs))
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let region = match plot_area_region {
    Some(p) => p
    None =>
      raise Malformed("<cx:plotArea> is missing required <cx:plotAreaRegion>")
  }
  { plot_area_region: region, axes, extension }
}

///|
fn parse_plot_area_region(
  r : @xml.XmlReader,
) -> ChartExPlotAreaRegion raise ChartExError {
  let mut plot_surface : @xml.XmlElement? = None
  let series : Array[ChartExSeries] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ex_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "plotSurface" =>
              plot_surface = Some(collect_subtree_unknown(r, child, attrs))
            "series" => series.push(parse_series(r, child, attrs))
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { plot_surface, series, extension }
}

///|
fn parse_series(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> ChartExSeries raise ChartExError {
  let layout_id = match optional_attr(attrs, "layoutId") {
    Some(s) => ChartExKind::from_xml(s)
    None =>
      raise Malformed("<cx:series> is missing required `layoutId` attribute")
  }
  let format_idx = parse_int_attr_opt(attrs, "formatIdx")
  let hidden = parse_bool_attr_opt(attrs, "hidden")
  let owner_idx = parse_int_attr_opt(attrs, "ownerIdx")
  // Capture the full `<cx:series>` element verbatim — the body's
  // children stay opaque for round-trip until a later slice types
  // them.
  let body = collect_subtree_unknown(r, name, attrs)
  { layout_id, format_idx, hidden, owner_idx, body }
}

// --- attribute helpers ---

///|
fn optional_attr(attrs : Array[(@xml.QName, String)], name : String) -> String? {
  @oxml.optional_attr(attrs, name)
}

///|
fn parse_int_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Int? {
  match optional_attr(attrs, name) {
    Some(v) => @oxml.parse_signed_int(v)
    None => None
  }
}

///|
fn parse_bool_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Bool? {
  match optional_attr(attrs, name) {
    Some(v) =>
      match v {
        "1" | "true" => Some(true)
        "0" | "false" => Some(false)
        _ => None
      }
    None => None
  }
}

// --- shared helpers ---

///|
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise ChartExError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise Malformed("unexpected end of input")
  }
}

///|
fn collect_subtree_unknown(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> @xml.XmlElement raise ChartExError {
  @oxml.collect_subtree(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise ChartExError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
}
