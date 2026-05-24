// High-level chart-from-scratch builders.
//
// The chart-family typed bodies (BarChartBody, LineChartBody,
// PieChartBody, …) carry their `<c:ser>` children as captured
// `XmlElement` payloads — series will get their own typed AST in a
// later slice. Builders here hide that XmlElement plumbing behind a
// data-oriented `ChartData` value, so callers can produce a complete
// `Chart` without touching the DOM:
//
//   let data = ChartData::new()
//     .with_category("Q1").with_category("Q2").with_category("Q3")
//     .with_series("Revenue", [100.0, 200.0, 300.0])
//     .with_series("Cost",    [ 50.0,  80.0, 120.0])
//   let chart = Chart::of_bar(data, bar_dir~ = Col)
//   let bytes = chart.serialize()
//
// Series are emitted with inline `<c:strLit>` categories and
// `<c:numLit>` values — no embedded XLSX cache, which keeps the
// builder pure-MoonBit and side-effect-free. PowerPoint accepts
// `strLit` / `numLit` in place of the `strRef` / `numRef` cache it
// normally emits; some renderers may degrade gracefully (showing
// the inline values verbatim) while others fully honour the data.

///|
/// Source-of-truth chart-data value object. Categories are the
/// shared horizontal axis labels (or pie-slice labels); each series
/// contributes a numeric value per category.
///
/// `ChartData` is immutable: every `with_*` call returns a new
/// value (matching ADR-003 throughout the codebase). The arrays are
/// not deep-cloned on each call — callers shouldn't mutate the
/// arrays they pass in.
pub(all) struct ChartData {
  /// Category labels, in display order.
  categories : Array[String]
  /// Each series carries its own label and a parallel array of
  /// numeric values (one entry per category).
  series : Array[ChartSeries]
} derive(Eq, Debug)

///|
pub impl Show for ChartData with fn output(self, logger) {
  logger.write_string("ChartData(")
  logger.write_string(self.categories.length().to_string())
  logger.write_string(" cats, ")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// One series in a `ChartData` value: a display label plus a value
/// per category.
pub(all) struct ChartSeries {
  /// Display label — used as the series legend entry.
  label : String
  /// Numeric values in category order. Shorter arrays are padded
  /// with zeros at emit time; longer arrays are truncated.
  values : Array[Double]
} derive(Eq, Debug)

///|
pub impl Show for ChartSeries with fn output(self, logger) {
  logger.write_string("ChartSeries(")
  logger.write_string(self.label)
  logger.write_string(", ")
  logger.write_string(self.values.length().to_string())
  logger.write_string(" values)")
}

///|
/// Empty chart-data value. Use `with_category` / `with_series` to
/// populate it.
pub fn ChartData::new() -> ChartData {
  { categories: [], series: [] }
}

///|
/// Append a category label.  Returns a new `ChartData` with the
/// added category.
pub fn ChartData::with_category(self : ChartData, c : String) -> ChartData {
  let cats : Array[String] = []
  for x in self.categories {
    cats.push(x)
  }
  cats.push(c)
  { categories: cats, series: self.series }
}

///|
/// Append a series. Returns a new `ChartData` with the added
/// series.
pub fn ChartData::with_series(
  self : ChartData,
  label : String,
  values : Array[Double],
) -> ChartData {
  let s : Array[ChartSeries] = []
  for x in self.series {
    s.push(x)
  }
  s.push({ label, values })
  { categories: self.categories, series: s }
}

// --- Chart-level constructor helpers ---

///|
/// Construct a complete bar / column chart from a `ChartData` value.
/// The two axes are the standard 2-D pair (catAx + valAx) with a
/// fixed `axId` pair of (`1`, `2`). `bar_dir` defaults to `Col`
/// (vertical columns); pass `Bar` for horizontal bars. `grouping`
/// defaults to `Clustered`.
pub fn Chart::of_bar(
  data : ChartData,
  bar_dir? : BarDir = Col,
  grouping? : BarGrouping = Clustered,
) -> Chart {
  let series_xml = synthesize_series(data)
  let bar : BarChartBody = {
    bar_dir,
    grouping: Some(grouping),
    vary_colors: None,
    series: series_xml,
    d_lbls: None,
    gap_width: None,
    overlap: None,
    ax_ids: [1, 2],
    extension: [],
  }
  let plot_area : PlotArea = {
    layout: None,
    plots: [BarChart(bar)],
    axes: [
      CatAx(simple_axis_element("catAx", 1, 2)),
      ValAx(simple_axis_element("valAx", 2, 1)),
    ],
    data_table: None,
    sp_pr: None,
    extension: [],
  }
  wrap_chart(plot_area)
}

///|
/// Construct a complete line chart from a `ChartData` value. Same
/// two-axis convention as `of_bar`. `grouping` defaults to `Standard`.
pub fn Chart::of_line(
  data : ChartData,
  grouping? : Grouping = Standard,
) -> Chart {
  let series_xml = synthesize_series(data)
  let line : LineChartBody = {
    grouping,
    vary_colors: None,
    series: series_xml,
    d_lbls: None,
    drop_lines: None,
    hi_low_lines: None,
    up_down_bars: None,
    marker: None,
    smooth: None,
    ax_ids: [1, 2],
    extension: [],
  }
  let plot_area : PlotArea = {
    layout: None,
    plots: [LineChart(line)],
    axes: [
      CatAx(simple_axis_element("catAx", 1, 2)),
      ValAx(simple_axis_element("valAx", 2, 1)),
    ],
    data_table: None,
    sp_pr: None,
    extension: [],
  }
  wrap_chart(plot_area)
}

///|
/// Construct a complete pie chart from a `ChartData` value. Pie
/// charts have no axes; the first series in `data` is used and the
/// remaining series are ignored (PowerPoint pie charts are
/// fundamentally single-series).
pub fn Chart::of_pie(data : ChartData) -> Chart {
  let series_xml = synthesize_series(data)
  let pie : PieChartBody = {
    vary_colors: Some(true),
    series: series_xml,
    d_lbls: None,
    first_slice_ang: None,
    extension: [],
  }
  let plot_area : PlotArea = {
    layout: None,
    plots: [PieChart(pie)],
    axes: [],
    data_table: None,
    sp_pr: None,
    extension: [],
  }
  wrap_chart(plot_area)
}

///|
/// Wrap a plot-area-only chart definition into the full Chart shape
/// (`<c:chartSpace>` ▸ `<c:chart>` ▸ plotArea).  Used by every
/// chart-level constructor here.
fn wrap_chart(plot_area : PlotArea) -> Chart {
  let chart : ChartBody = {
    title: None,
    auto_title_deleted: None,
    pivot_fmts: None,
    view3d: None,
    floor: None,
    side_wall: None,
    back_wall: None,
    plot_area,
    legend: None,
    plot_vis_only: Some(true),
    disp_blanks_as: Some(Gap),
    show_d_lbls_over_max: None,
    extension: [],
  }
  {
    date1904: None,
    lang: Some("en-US"),
    rounded_corners: None,
    style: None,
    chart,
    extension: [],
  }
}

// --- inline series-XmlElement synthesis ---

///|
/// Build one `<c:ser>` element per `ChartSeries`, each carrying
/// inline `<c:strLit>` categories and `<c:numLit>` values. The
/// series `idx` and `order` attributes are assigned sequentially.
fn synthesize_series(data : ChartData) -> Array[@xml.XmlElement] {
  let out : Array[@xml.XmlElement] = []
  for i, s in data.series {
    out.push(synthesize_one_series(i, s, data.categories))
  }
  out
}

///|
fn synthesize_one_series(
  index : Int,
  s : ChartSeries,
  categories : Array[String],
) -> @xml.XmlElement {
  let children : Array[@xml.XmlNode] = []
  children.push(Element(val_leaf("idx", index.to_string())))
  children.push(Element(val_leaf("order", index.to_string())))
  // <c:tx><c:v>label</c:v></c:tx> — series-title alternative to strRef
  children.push(
    Element(c_elem("tx", [], [Element(c_elem("v", [], [Text(s.label)]))])),
  )
  children.push(Element(category_axis_data_lit(categories)))
  children.push(Element(numeric_data_lit("val", s.values, categories.length())))
  c_elem("ser", [], children)
}

///|
/// `<c:cat><c:strLit>…</c:strLit></c:cat>` — the categorical axis
/// data source, inline-literal flavour.
fn category_axis_data_lit(categories : Array[String]) -> @xml.XmlElement {
  let pts : Array[@xml.XmlNode] = []
  pts.push(Element(val_leaf("ptCount", categories.length().to_string())))
  for i, c in categories {
    pts.push(Element(pt_leaf(i, c)))
  }
  let str_lit = c_elem("strLit", [], pts)
  c_elem("cat", [], [Element(str_lit)])
}

///|
/// `<c:val><c:numLit>…</c:numLit></c:val>` or `<c:bubbleSize>` —
/// the numeric data source, inline-literal flavour. `count` is the
/// expected entry count; values shorter than that are padded with
/// zeros, longer arrays are truncated.
fn numeric_data_lit(
  parent_local_name : String,
  values : Array[Double],
  count : Int,
) -> @xml.XmlElement {
  let pts : Array[@xml.XmlNode] = []
  pts.push(Element(val_leaf("ptCount", count.to_string())))
  for i in 0..<count {
    let v = if i < values.length() { values[i] } else { 0.0 }
    pts.push(Element(pt_leaf(i, v.to_string())))
  }
  let num_lit = c_elem("numLit", [], pts)
  c_elem(parent_local_name, [], [Element(num_lit)])
}

///|
/// `<c:pt idx="…"><c:v>…</c:v></c:pt>` — one indexed data point
/// inside a `<c:strLit>` or `<c:numLit>`.
fn pt_leaf(index : Int, text : String) -> @xml.XmlElement {
  c_elem("pt", [(@xml.QName::unqualified("idx"), index.to_string())], [
    Element(c_elem("v", [], [Text(text)])),
  ])
}

///|
/// `<c:foo val="…"/>` — the boilerplate single-attribute leaf used
/// for `idx`, `order`, `ptCount`, axId references, etc.
fn val_leaf(local_name : String, val : String) -> @xml.XmlElement {
  c_elem(local_name, [(@xml.QName::unqualified("val"), val)], [])
}

///|
/// `<c:catAx>` / `<c:valAx>` skeleton with the minimum children
/// PowerPoint expects: an axId, plus a crossAx reference to the
/// paired axis. Other styling fields stay at defaults.
fn simple_axis_element(
  local_name : String,
  self_id : Int,
  cross_id : Int,
) -> @xml.XmlElement {
  c_elem(local_name, [], [
    Element(val_leaf("axId", self_id.to_string())),
    Element(c_elem("scaling", [], [Element(val_leaf("orientation", "minMax"))])),
    Element(val_leaf("delete", "0")),
    Element(val_leaf("axPos", default_ax_pos(local_name))),
    Element(val_leaf("crossAx", cross_id.to_string())),
  ])
}

///|
/// Default `<c:axPos>` value for each axis kind. Category axes sit
/// at the bottom; value axes on the left, when the chart is a
/// vertical column. (Horizontal bar charts swap; users that need
/// that can re-emit the axis themselves.)
fn default_ax_pos(local_name : String) -> String {
  match local_name {
    "catAx" => "b" // bottom
    "valAx" => "l" // left
    _ => "b"
  }
}

///|
/// Helper: construct a chart-namespace `XmlElement` with the given
/// local name, attributes, and child nodes.
fn c_elem(
  local_name : String,
  attributes : Array[(@xml.QName, String)],
  children : Array[@xml.XmlNode],
) -> @xml.XmlElement {
  @xml.XmlElement::new(
    @xml.QName::new(@oxml.chart_ns, local_name),
    attributes,
    children,
  )
}
