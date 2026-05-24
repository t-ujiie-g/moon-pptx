// Chart XML reader.
//
// Walks `<c:chartSpace>` → `<c:chart>` → `<c:plotArea>` → plot family
// bodies / axes. Each level peels off the scalar / enum leaves it
// knows about and either captures the substantial subtrees as
// `XmlElement` (lossless preservation per ADR-004) or descends into
// a typed body parser when the family has been lifted. The list of
// typed chart-family bodies grows over time; untyped families keep
// round-tripping through the captured-element fallback.

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
/// Typed variants walk their captured `<XmlElement>` to produce a
/// typed body; untyped variants stay as wholesale captures.
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
/// Walk a captured `<c:barChart>` element into a typed
/// `BarChartBody`. The schema specifies a fixed child order
/// (`barDir` → `grouping` → `varyColors` → `ser*` → `dLbls` →
/// `gapWidth` → `overlap` → `axId{2,3}` → `extLst`), but the parser
/// tolerates any order — we just dispatch on local-name.
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
/// `LineChartBody`.
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
/// `PieChartBody`. Pie charts have no axIds and the schema
/// doesn't mark any leaf as required, so the parser never raises
/// Malformed for a missing-child reason here.
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

// --- area / 3-D variants / doughnut / radar parsers ---

///|
fn parse_area_chart(el : @xml.XmlElement) -> AreaChartBody {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut drop_lines : @xml.XmlElement? = None
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
  { grouping, vary_colors, series, d_lbls, drop_lines, ax_ids, extension }
}

///|
fn parse_area_3d_chart(el : @xml.XmlElement) -> Area3DChartBody {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut drop_lines : @xml.XmlElement? = None
  let mut gap_depth : Int? = None
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
            "gapDepth" => gap_depth = parse_val_int_attr(c.attributes)
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
  {
    grouping,
    vary_colors,
    series,
    d_lbls,
    drop_lines,
    gap_depth,
    ax_ids,
    extension,
  }
}

///|
fn parse_bar_3d_chart(el : @xml.XmlElement) -> Bar3DChartBody raise ChartError {
  let mut bar_dir : BarDir? = None
  let mut grouping : BarGrouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut gap_width : Int? = None
  let mut gap_depth : Int? = None
  let mut shape : BarShape? = None
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
            "gapDepth" => gap_depth = parse_val_int_attr(c.attributes)
            "shape" =>
              shape = parse_val_string_attr(c.attributes).bind(
                BarShape::from_xml,
              )
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
    None => raise Malformed("<c:bar3DChart> is missing required <c:barDir>")
  }
  {
    bar_dir: bd,
    grouping,
    vary_colors,
    series,
    d_lbls,
    gap_width,
    gap_depth,
    shape,
    ax_ids,
    extension,
  }
}

///|
fn parse_line_3d_chart(
  el : @xml.XmlElement,
) -> Line3DChartBody raise ChartError {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut drop_lines : @xml.XmlElement? = None
  let mut gap_depth : Int? = None
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
            "gapDepth" => gap_depth = parse_val_int_attr(c.attributes)
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
    None => raise Malformed("<c:line3DChart> is missing required <c:grouping>")
  }
  {
    grouping: g,
    vary_colors,
    series,
    d_lbls,
    drop_lines,
    gap_depth,
    ax_ids,
    extension,
  }
}

///|
fn parse_pie_3d_chart(el : @xml.XmlElement) -> Pie3DChartBody {
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
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
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { vary_colors, series, d_lbls, extension }
}

///|
fn parse_doughnut_chart(el : @xml.XmlElement) -> DoughnutChartBody {
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut first_slice_ang : Int? = None
  let mut hole_size : Int? = None
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
            "holeSize" => hole_size = parse_val_int_attr(c.attributes)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { vary_colors, series, d_lbls, first_slice_ang, hole_size, extension }
}

///|
fn parse_radar_chart(el : @xml.XmlElement) -> RadarChartBody raise ChartError {
  let mut radar_style : RadarStyle? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "radarStyle" =>
              radar_style = parse_val_string_attr(c.attributes).bind(
                RadarStyle::from_xml,
              )
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
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
  let rs = match radar_style {
    Some(s) => s
    None => raise Malformed("<c:radarChart> is missing required <c:radarStyle>")
  }
  { radar_style: rs, vary_colors, series, d_lbls, ax_ids, extension }
}

// --- scatter / bubble / stock / surface / surface3D / ofPie parsers ---

///|
fn parse_scatter_chart(
  el : @xml.XmlElement,
) -> ScatterChartBody raise ChartError {
  let mut scatter_style : ScatterStyle? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "scatterStyle" =>
              scatter_style = parse_val_string_attr(c.attributes).bind(
                ScatterStyle::from_xml,
              )
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
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
  let ss = match scatter_style {
    Some(s) => s
    None =>
      raise Malformed("<c:scatterChart> is missing required <c:scatterStyle>")
  }
  { scatter_style: ss, vary_colors, series, d_lbls, ax_ids, extension }
}

///|
fn parse_bubble_chart(el : @xml.XmlElement) -> BubbleChartBody {
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut bubble_3d : Bool? = None
  let mut bubble_scale : Int? = None
  let mut show_neg_bubbles : Bool? = None
  let mut size_represents : SizeRepresents? = None
  let ax_ids : Array[Int] = []
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
            "bubble3D" => bubble_3d = parse_val_bool_attr(c.attributes)
            "bubbleScale" => bubble_scale = parse_val_int_attr(c.attributes)
            "showNegBubbles" =>
              show_neg_bubbles = parse_val_bool_attr(c.attributes)
            "sizeRepresents" =>
              size_represents = parse_val_string_attr(c.attributes).bind(
                SizeRepresents::from_xml,
              )
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
  {
    vary_colors,
    series,
    d_lbls,
    bubble_3d,
    bubble_scale,
    show_neg_bubbles,
    size_represents,
    ax_ids,
    extension,
  }
}

///|
fn parse_stock_chart(el : @xml.XmlElement) -> StockChartBody {
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut drop_lines : @xml.XmlElement? = None
  let mut hi_low_lines : @xml.XmlElement? = None
  let mut up_down_bars : @xml.XmlElement? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
            "dropLines" => drop_lines = Some(c)
            "hiLowLines" => hi_low_lines = Some(c)
            "upDownBars" => up_down_bars = Some(c)
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
  { series, d_lbls, drop_lines, hi_low_lines, up_down_bars, ax_ids, extension }
}

///|
fn parse_surface_chart(el : @xml.XmlElement) -> SurfaceChartBody {
  let mut wireframe : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut band_fmts : @xml.XmlElement? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "wireframe" => wireframe = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "bandFmts" => band_fmts = Some(c)
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
  { wireframe, series, band_fmts, ax_ids, extension }
}

///|
fn parse_surface_3d_chart(el : @xml.XmlElement) -> Surface3DChartBody {
  let mut wireframe : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut band_fmts : @xml.XmlElement? = None
  let ax_ids : Array[Int] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "wireframe" => wireframe = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "bandFmts" => band_fmts = Some(c)
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
  { wireframe, series, band_fmts, ax_ids, extension }
}

///|
fn parse_of_pie_chart(el : @xml.XmlElement) -> OfPieChartBody raise ChartError {
  let mut of_pie_type : OfPieType? = None
  let mut vary_colors : Bool? = None
  let series : Array[@xml.XmlElement] = []
  let mut d_lbls : @xml.XmlElement? = None
  let mut gap_width : Int? = None
  let mut split_type : SplitType? = None
  let mut split_pos : String? = None
  let mut cust_split : @xml.XmlElement? = None
  let mut second_pie_size : Int? = None
  let ser_lines : Array[@xml.XmlElement] = []
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "ofPieType" =>
              of_pie_type = parse_val_string_attr(c.attributes).bind(
                OfPieType::from_xml,
              )
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(c)
            "dLbls" => d_lbls = Some(c)
            "gapWidth" => gap_width = parse_val_int_attr(c.attributes)
            "splitType" =>
              split_type = parse_val_string_attr(c.attributes).bind(
                SplitType::from_xml,
              )
            "splitPos" => split_pos = parse_val_string_attr(c.attributes)
            "custSplit" => cust_split = Some(c)
            "secondPieSize" =>
              second_pie_size = parse_val_int_attr(c.attributes)
            "serLines" => ser_lines.push(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let opt = match of_pie_type {
    Some(t) => t
    None => raise Malformed("<c:ofPieChart> is missing required <c:ofPieType>")
  }
  {
    of_pie_type: opt,
    vary_colors,
    series,
    d_lbls,
    gap_width,
    split_type,
    split_pos,
    cust_split,
    second_pie_size,
    ser_lines,
    extension,
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
