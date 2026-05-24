// Chart XML reader — Phase 7a1 + 7a2 + 7a3a.
//
// Phase 7a1 introduced the streaming entry point and captured the
// entire `<c:chartSpace>` body wholesale. Phase 7a2 walks that body
// instead, peels off the chartSpace-level scalar fields (`date1904`,
// `lang`, `roundedCorners`, `style`), descends into `<c:chart>` and
// lifts the scalar / enum-valued header leaves there
// (`autoTitleDeleted`, `plotVisOnly`, `dispBlanksAs`,
// `showDLblsOverMax`). Phase 7a3a lifts the `<c:plotArea>` body —
// the structural skeleton (layout / plots / axes / dTable / spPr /
// extension) is typed; individual plot-family bodies and axis bodies
// still ride as captured XmlElement payloads inside their respective
// `Plot` / `Axis` variants until later 7a slices type them.

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
  let mut title : @xml.XmlElement? = None
  let mut auto_title_deleted : Bool? = None
  let mut pivot_fmts : @xml.XmlElement? = None
  let mut view3d : @xml.XmlElement? = None
  let mut floor : @xml.XmlElement? = None
  let mut side_wall : @xml.XmlElement? = None
  let mut back_wall : @xml.XmlElement? = None
  let mut plot_area : PlotArea? = None
  let mut legend : @xml.XmlElement? = None
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
            "title" => title = Some(collect_subtree_unknown(r, child, attrs))
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
            "legend" => legend = Some(collect_subtree_unknown(r, child, attrs))
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

// --- plotArea (7a3a) ---

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
/// Dispatch a chart-namespace element local-name to a `Plot` variant
/// carrying the captured `XmlElement`. Returns `None` for non-plot
/// elements.
fn plot_from_local_name(name : String, el : @xml.XmlElement) -> Plot? {
  match name {
    "areaChart" => Some(AreaChart(el))
    "area3DChart" => Some(Area3DChart(el))
    "lineChart" => Some(LineChart(el))
    "line3DChart" => Some(Line3DChart(el))
    "stockChart" => Some(StockChart(el))
    "radarChart" => Some(RadarChart(el))
    "scatterChart" => Some(ScatterChart(el))
    "pieChart" => Some(PieChart(el))
    "pie3DChart" => Some(Pie3DChart(el))
    "doughnutChart" => Some(DoughnutChart(el))
    "barChart" => Some(BarChart(el))
    "bar3DChart" => Some(Bar3DChart(el))
    "ofPieChart" => Some(OfPieChart(el))
    "surfaceChart" => Some(SurfaceChart(el))
    "surface3DChart" => Some(Surface3DChart(el))
    "bubbleChart" => Some(BubbleChart(el))
    _ => None
  }
}

///|
/// Dispatch a chart-namespace element local-name to an `Axis`
/// variant. Returns `None` for non-axis elements.
fn axis_from_local_name(name : String, el : @xml.XmlElement) -> Axis? {
  match name {
    "valAx" => Some(ValAx(el))
    "catAx" => Some(CatAx(el))
    "dateAx" => Some(DateAx(el))
    "serAx" => Some(SerAx(el))
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
