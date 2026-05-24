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
/// Dispatch a chart-namespace element local-name to a `Plot` variant.
/// Typed variants (currently `barChart` — Phase 7a3b) walk their
/// captured `<XmlElement>` to produce a typed body; the remaining
/// variants stay as wholesale captures until later 7a slices.
///
/// Returns `None` for non-plot elements (the caller continues to
/// `axis_from_local_name`).
fn plot_from_local_name(
  name : String,
  el : @xml.XmlElement,
) -> Plot? raise ChartError {
  match name {
    "areaChart" => Some(AreaChart(el))
    "area3DChart" => Some(Area3DChart(el))
    "lineChart" => Some(LineChart(parse_line_chart(el)))
    "line3DChart" => Some(Line3DChart(el))
    "stockChart" => Some(StockChart(el))
    "radarChart" => Some(RadarChart(el))
    "scatterChart" => Some(ScatterChart(el))
    "pieChart" => Some(PieChart(parse_pie_chart(el)))
    "pie3DChart" => Some(Pie3DChart(el))
    "doughnutChart" => Some(DoughnutChart(el))
    "barChart" => Some(BarChart(parse_bar_chart(el)))
    "bar3DChart" => Some(Bar3DChart(el))
    "ofPieChart" => Some(OfPieChart(el))
    "surfaceChart" => Some(SurfaceChart(el))
    "surface3DChart" => Some(Surface3DChart(el))
    "bubbleChart" => Some(BubbleChart(el))
    _ => None
  }
}

///|
/// Walk a captured `<c:barChart>` element into a typed
/// `BarChartBody`. Element order in the source XML is the schema
/// order (`barDir` → `grouping` → `varyColors` → `ser*` → `dLbls`
/// → `gapWidth` → `overlap` → `axId{2,3}` → `extLst`), but the
/// parser tolerates any order — we just dispatch on local-name.
fn parse_bar_chart(el : @xml.XmlElement) -> BarChartBody raise ChartError {
  let mut bar_dir : BarDir? = None
  let mut grouping : BarGrouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut gap_width : Int? = None
  let mut overlap : Int? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "barDir" =>
              bar_dir = parse_val_string_attr(c.attributes).bind(
                BarDir::from_xml,
              )
            "grouping" =>
              grouping = parse_val_string_attr(c.attributes).bind(
                BarGrouping::from_xml,
              )
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
            "gapWidth" => gap_width = parse_val_int_attr(c.attributes)
            "overlap" => overlap = parse_val_int_attr(c.attributes)
            "axId" =>
              match parse_val_int_attr(c.attributes) {
                Some(n) => ax_ids.push(n)
                None => ()
              }
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let bd = match bar_dir {
    Some(d) => d
    None => raise Malformed("<c:barChart> is missing required <c:barDir>")
  }
  {
    bar_dir: bd,
    grouping,
    vary_colors,
    series,
    d_lbls,
    gap_width,
    overlap,
    ax_ids,
    extension,
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

///|
/// Walk a captured `<c:lineChart>` element into a typed
/// `LineChartBody`. Phase 7a3c.
fn parse_line_chart(el : @xml.XmlElement) -> LineChartBody raise ChartError {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut drop_lines : @xml.XmlElement? = None
  let mut hi_low_lines : @xml.XmlElement? = None
  let mut up_down_bars : @xml.XmlElement? = None
  let mut marker : Bool? = None
  let mut smooth : Bool? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "grouping" =>
              grouping = parse_val_string_attr(c.attributes).bind(
                Grouping::from_xml,
              )
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
            "dropLines" => drop_lines = Some(c)
            "hiLowLines" => hi_low_lines = Some(c)
            "upDownBars" => up_down_bars = Some(c)
            "marker" => marker = parse_val_bool_attr(c.attributes)
            "smooth" => smooth = parse_val_bool_attr(c.attributes)
            "axId" =>
              match parse_val_int_attr(c.attributes) {
                Some(n) => ax_ids.push(n)
                None => ()
              }
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let g = match grouping {
    Some(g) => g
    None => raise Malformed("<c:lineChart> is missing required <c:grouping>")
  }
  {
    grouping: g,
    vary_colors,
    series,
    d_lbls,
    drop_lines,
    hi_low_lines,
    up_down_bars,
    marker,
    smooth,
    ax_ids,
    extension,
  }
}

///|
/// Walk a captured `<c:pieChart>` element into a typed
/// `PieChartBody`. Phase 7a3d. Pie charts have no axIds — the
/// schema doesn't require any required scalar fields, so the
/// parser never raises Malformed for a missing-child reason here.
fn parse_pie_chart(el : @xml.XmlElement) -> PieChartBody {
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut first_slice_ang : Int? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
            "firstSliceAng" =>
              first_slice_ang = parse_val_int_attr(c.attributes)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { vary_colors, series, d_lbls, first_slice_ang, extension }
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
