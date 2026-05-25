// Chart XML reader.
//
// Walks `<c:chartSpace>` → `<c:chart>` → `<c:plotArea>` → plot family
// bodies / axes. Each level peels off the scalar / enum leaves it
// knows about and either captures the substantial subtrees as
// `XmlElement` (lossless preservation per ADR-004) or descends into
// a typed body parser when the family has been lifted.
//
// The per-family parsers (`parse_bar_chart`, `parse_line_chart`, …)
// live in `plot_parsers.mbt`. This file owns the top-level walk,
// the family-dispatch table, and the shared attribute/event helpers.

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
  let name = match event {
    StartElement(n, _) => n
    _ => raise Malformed("expected <c:chartSpace> root element")
  }
  if name.uri != @oxml.chart_ns || name.local_name != "chartSpace" {
    raise Malformed(
      "expected <c:chartSpace> root but got <" + name.local_name + ">",
    )
  }
  parse_chart_space(r)
}

///|
/// Walk the `<c:chartSpace>` body. Caller has already consumed the
/// `<c:chartSpace>` StartElement.
fn parse_chart_space(r : @xml.XmlReader) -> Chart raise ChartError {
  let mut date1904 : Bool? = None
  let mut lang : String? = None
  let mut rounded_corners : Bool? = None
  let mut style : Int? = None
  let mut chart_body : ChartBody? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "date1904" => {
              date1904 = parse_val_bool_attr(attrs)
              skip_subtree(r)
            }
            "lang" => {
              lang = parse_val_string_attr(attrs)
              skip_subtree(r)
            }
            "roundedCorners" => {
              rounded_corners = parse_val_bool_attr(attrs)
              skip_subtree(r)
            }
            "style" => {
              style = parse_val_int_attr(attrs)
              skip_subtree(r)
            }
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
    None => raise Malformed("<c:chartSpace> is missing required <c:chart>")
  }
  { date1904, lang, rounded_corners, style, chart, extension }
}

///|
/// Walk `<c:chart>` body. Caller has consumed the `<c:chart>`
/// StartElement.
fn parse_chart_body(r : @xml.XmlReader) -> ChartBody raise ChartError {
  let mut title : ChartTitle? = None
  let mut auto_title_deleted : Bool? = None
  let mut pivot_fmts : @xml.XmlElement? = None
  let mut view3d : @xml.XmlElement? = None
  let mut floor : @xml.XmlElement? = None
  let mut side_wall : @xml.XmlElement? = None
  let mut back_wall : @xml.XmlElement? = None
  let mut plot_area : PlotArea? = None
  let mut legend : ChartLegend? = None
  let mut plot_vis_only : Bool? = None
  let mut disp_blanks_as : DisplayBlanksAs? = None
  let mut show_d_lbls_over_max : Bool? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "title" =>
              title = Some(
                parse_chart_title(collect_subtree_unknown(r, child, attrs)),
              )
            "autoTitleDeleted" => {
              auto_title_deleted = parse_val_bool_attr(attrs)
              skip_subtree(r)
            }
            "pivotFmts" =>
              pivot_fmts = Some(collect_subtree_unknown(r, child, attrs))
            "view3D" => view3d = Some(collect_subtree_unknown(r, child, attrs))
            "floor" => floor = Some(collect_subtree_unknown(r, child, attrs))
            "sideWall" =>
              side_wall = Some(collect_subtree_unknown(r, child, attrs))
            "backWall" =>
              back_wall = Some(collect_subtree_unknown(r, child, attrs))
            "plotArea" => plot_area = Some(parse_plot_area(r))
            "legend" =>
              legend = Some(
                parse_chart_legend(collect_subtree_unknown(r, child, attrs)),
              )
            "plotVisOnly" => {
              plot_vis_only = parse_val_bool_attr(attrs)
              skip_subtree(r)
            }
            "dispBlanksAs" => {
              let v = parse_val_string_attr(attrs)
              disp_blanks_as = match v {
                Some(s) => DisplayBlanksAs::from_xml(s)
                None => None
              }
              skip_subtree(r)
            }
            "showDLblsOverMax" => {
              show_d_lbls_over_max = parse_val_bool_attr(attrs)
              skip_subtree(r)
            }
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let plot = match plot_area {
    Some(p) => p
    None => raise Malformed("<c:chart> is missing required <c:plotArea>")
  }
  {
    title,
    auto_title_deleted,
    pivot_fmts,
    view3d,
    floor,
    side_wall,
    back_wall,
    plot_area: plot,
    legend,
    plot_vis_only,
    disp_blanks_as,
    show_d_lbls_over_max,
    extension,
  }
}

// --- plotArea ---

///|
/// Walk a `<c:plotArea>` body. Caller has consumed the
/// `<c:plotArea>` StartElement.
fn parse_plot_area(r : @xml.XmlReader) -> PlotArea raise ChartError {
  let mut layout : @xml.XmlElement? = None
  let plots : Array[Plot] = []
  let axes : Array[Axis] = []
  let mut data_table : @xml.XmlElement? = None
  let mut sp_pr : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.chart_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          let el = collect_subtree_unknown(r, child, attrs)
          match plot_from_local_name(child.local_name, el) {
            Some(p) => plots.push(p)
            None =>
              match axis_from_local_name(child.local_name, el) {
                Some(a) => axes.push(a)
                None =>
                  match child.local_name {
                    "layout" => layout = Some(el)
                    "dTable" => data_table = Some(el)
                    "spPr" => sp_pr = Some(el)
                    _ => extension.push(el)
                  }
              }
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { layout, plots, axes, data_table, sp_pr, extension }
}

///|
/// Dispatch a chart-namespace element local-name to a `Plot` variant.
/// Per-family bodies live in `plot_parsers.mbt`.
///
/// Returns `None` for non-plot elements (the caller continues to
/// `axis_from_local_name`).
fn plot_from_local_name(
  name : String,
  el : @xml.XmlElement,
) -> Plot? raise ChartError {
  match name {
    "areaChart" => Some(AreaChart(parse_area_chart(el)))
    "area3DChart" => Some(Area3DChart(parse_area_3d_chart(el)))
    "lineChart" => Some(LineChart(parse_line_chart(el)))
    "line3DChart" => Some(Line3DChart(parse_line_3d_chart(el)))
    "stockChart" => Some(StockChart(parse_stock_chart(el)))
    "radarChart" => Some(RadarChart(parse_radar_chart(el)))
    "scatterChart" => Some(ScatterChart(parse_scatter_chart(el)))
    "pieChart" => Some(PieChart(parse_pie_chart(el)))
    "pie3DChart" => Some(Pie3DChart(parse_pie_3d_chart(el)))
    "doughnutChart" => Some(DoughnutChart(parse_doughnut_chart(el)))
    "barChart" => Some(BarChart(parse_bar_chart(el)))
    "bar3DChart" => Some(Bar3DChart(parse_bar_3d_chart(el)))
    "ofPieChart" => Some(OfPieChart(parse_of_pie_chart(el)))
    "surfaceChart" => Some(SurfaceChart(parse_surface_chart(el)))
    "surface3DChart" => Some(Surface3DChart(parse_surface_3d_chart(el)))
    "bubbleChart" => Some(BubbleChart(parse_bubble_chart(el)))
    _ => None
  }
}

///|
/// Dispatch a chart-namespace element local-name to an `Axis`
/// variant. Returns `None` for non-axis elements.
fn axis_from_local_name(
  name : String,
  el : @xml.XmlElement,
) -> Axis? raise ChartError {
  match name {
    "valAx" => Some(ValAx(parse_axis_core(el)))
    "catAx" => Some(CatAx(parse_axis_core(el)))
    "dateAx" => Some(DateAx(parse_axis_core(el)))
    "serAx" => Some(SerAx(parse_axis_core(el)))
    _ => None
  }
}

// --- attribute helpers ---

///|
/// Pull a `val="…"` attribute and parse as a Bool. The chart schema
/// uses `<c:fooBool val="1"/>` everywhere — a single helper covers
/// every Bool leaf.
///
/// Returns `None` when the attribute is absent (schema says required
/// but missing tolerantly resolves to the default per `CT_Boolean`'s
/// default; we surface `None` so callers can distinguish "absent"
/// from a parsed value).
fn parse_val_bool_attr(attrs : Array[(@xml.QName, String)]) -> Bool? {
  match @oxml.optional_attr(attrs, "val") {
    Some(v) =>
      match v {
        "1" | "true" => Some(true)
        "0" | "false" => Some(false)
        _ => None
      }
    None => None
  }
}

///|
/// Pull a `val="…"` attribute and parse as an Int. Returns `None`
/// when absent or unparseable.
fn parse_val_int_attr(attrs : Array[(@xml.QName, String)]) -> Int? {
  match @oxml.optional_attr(attrs, "val") {
    Some(v) => @oxml.parse_signed_int(v)
    None => None
  }
}

///|
/// Pull a `val="…"` attribute as a raw String, or `None` when absent.
fn parse_val_string_attr(attrs : Array[(@xml.QName, String)]) -> String? {
  @oxml.optional_attr(attrs, "val")
}

// --- shared event helpers ---

///|
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise ChartError {
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
) -> @xml.XmlElement raise ChartError {
  @oxml.collect_subtree(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn skip_subtree(r : @xml.XmlReader) -> Unit raise ChartError {
  @oxml.skip_subtree(r) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise ChartError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
}
