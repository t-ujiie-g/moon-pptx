// Per-family `<c:*Chart>` body parsers.
//
// Each function walks a captured `<XmlElement>` and produces the typed
// `*ChartBody` for one chart-family kind. All sixteen kinds defined in
// `EG_PlotAreaContent` (areaChart, area3DChart, lineChart, line3DChart,
// stockChart, radarChart, scatterChart, pieChart, pie3DChart,
// doughnutChart, barChart, bar3DChart, ofPieChart, surfaceChart,
// surface3DChart, bubbleChart) have their own parser here.
//
// Element-name dispatch lives in `parser.mbt` (`plot_from_local_name`).
// The val-attribute helpers (`parse_val_bool_attr` /
// `parse_val_int_attr` / `parse_val_string_attr`) are shared with the
// top-level walker and also live in `parser.mbt`.

///|
/// Walk a captured `<c:barChart>` element into a typed `BarChartBody`.
/// The schema specifies a fixed child order (`barDir` → `grouping` →
/// `varyColors` → `ser*` → `dLbls` → `gapWidth` → `overlap` →
/// `axId{2,3}` → `extLst`), but the parser tolerates any order — we
/// just dispatch on local-name.
fn parse_bar_chart(el : @xml.XmlElement) -> BarChartBody raise ChartError {
  let mut bar_dir : BarDir? = None
  let mut grouping : BarGrouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
/// Walk a captured `<c:lineChart>` element into a typed `LineChartBody`.
fn parse_line_chart(el : @xml.XmlElement) -> LineChartBody raise ChartError {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
/// Walk a captured `<c:pieChart>` element into a typed `PieChartBody`.
/// Pie charts have no axIds and the schema doesn't mark any leaf as
/// required, so the parser never raises Malformed for a missing-child
/// reason here.
fn parse_pie_chart(el : @xml.XmlElement) -> PieChartBody raise ChartError {
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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

// --- area / 3-D variants / doughnut / radar ---

///|
fn parse_area_chart(el : @xml.XmlElement) -> AreaChartBody raise ChartError {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
fn parse_area_3d_chart(
  el : @xml.XmlElement,
) -> Area3DChartBody raise ChartError {
  let mut grouping : Grouping? = None
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
fn parse_pie_3d_chart(el : @xml.XmlElement) -> Pie3DChartBody raise ChartError {
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "varyColors" => vary_colors = parse_val_bool_attr(c.attributes)
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { vary_colors, series, d_lbls, extension }
}

///|
fn parse_doughnut_chart(
  el : @xml.XmlElement,
) -> DoughnutChartBody raise ChartError {
  let mut vary_colors : Bool? = None
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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

// --- scatter / bubble / stock / surface / ofPie ---

///|
fn parse_scatter_chart(
  el : @xml.XmlElement,
) -> ScatterChartBody raise ChartError {
  let mut scatter_style : ScatterStyle? = None
  let mut vary_colors : Bool? = None
  let series : Array[ScatterSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_scatter_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
fn parse_bubble_chart(el : @xml.XmlElement) -> BubbleChartBody raise ChartError {
  let mut vary_colors : Bool? = None
  let series : Array[BubbleSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_bubble_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
fn parse_stock_chart(el : @xml.XmlElement) -> StockChartBody raise ChartError {
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
fn parse_surface_chart(
  el : @xml.XmlElement,
) -> SurfaceChartBody raise ChartError {
  let mut wireframe : Bool? = None
  let series : Array[ChartSeriesCore] = []
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
            "ser" => series.push(parse_chart_series_core(c))
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
fn parse_surface_3d_chart(
  el : @xml.XmlElement,
) -> Surface3DChartBody raise ChartError {
  let mut wireframe : Bool? = None
  let series : Array[ChartSeriesCore] = []
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
            "ser" => series.push(parse_chart_series_core(c))
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
  let series : Array[ChartSeriesCore] = []
  let mut d_lbls : DLbls? = None
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
            "ser" => series.push(parse_chart_series_core(c))
            "dLbls" => d_lbls = Some(parse_d_lbls(c))
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
