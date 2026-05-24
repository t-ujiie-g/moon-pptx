// Chart model — top-level Chart / ChartBody types.
//
// A chart part (`/ppt/charts/chartN.xml`) is rooted at
// `<c:chartSpace>` (DrawingML chart namespace,
// `http://schemas.openxmlformats.org/drawingml/2006/chart`).
//
// `<c:chartSpace>` (ECMA-376 §21.2.2.29, `CT_ChartSpace`) wraps:
//
//   <c:date1904>       (Bool — workbook epoch flag, optional)
//   <c:lang>           (String — natural language, optional)
//   <c:roundedCorners> (Bool — optional)
//   <c:style>          (UInt — preset style, optional)
//   <c:clrMapOvr>      (optional)
//   <c:pivotSource>    (optional)
//   <c:protection>     (optional)
//   <c:chart>          (CT_Chart — REQUIRED; the actual chart definition)
//   <c:spPr>           (shape properties — optional)
//   <c:txPr>           (text properties — optional)
//   <c:externalData>   (rId reference to embedded XLSX — optional)
//   <c:printSettings>  (optional)
//   <c:userShapes>     (rId reference — optional)
//   <c:extLst>         (extension list — optional)
//
// Untyped subtrees (title, legend, plotArea-side untyped axes, the
// 3-D wrappers, clrMapOvr, pivotSource, protection, spPr, txPr,
// externalData, printSettings, userShapes, extLst, plus foreign-
// namespace children) ride on their enclosing element's `extension`
// array per ADR-004.

///|
/// A parsed chart part (`/ppt/charts/chartN.xml`).
pub(all) struct Chart {
  /// `<c:date1904>` — workbook epoch flag. `None` when absent.
  date1904 : Bool?
  /// `<c:lang>` — natural language identifier (e.g. `en-US`).
  /// `None` when absent.
  lang : String?
  /// `<c:roundedCorners>` — `None` when absent.
  rounded_corners : Bool?
  /// `<c:style>` — preset style index (1..48 in practice). `None`
  /// when absent.
  style : Int?
  /// `<c:chart>` — REQUIRED chart definition body.
  chart : ChartBody
  /// chartSpace-level unmodelled children: clrMapOvr / pivotSource /
  /// protection / spPr / txPr / externalData / printSettings /
  /// userShapes / extLst plus any foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Chart with fn output(self, logger) {
  // `assert_eq` requires Show; derive(Debug) gives us the diagnostic
  // payload. Keep this stub minimal to avoid invoking Show on
  // container fields (Option / Array) — current `core` deprecates
  // that path in favour of Debug.
  let _ = self
  logger.write_string("Chart { … }")
}

///|
/// `<c:chart>` body (ECMA-376 §21.2.2.6, `CT_Chart`). Most of the
/// children are themselves substantial subtrees (title, legend,
/// 3-D wrappers) and are kept as captured `XmlElement?` here until
/// later slices type them. The scalar / enum-valued leaves
/// (`autoTitleDeleted`, `plotVisOnly`, `dispBlanksAs`,
/// `showDLblsOverMax`) are typed.
pub(all) struct ChartBody {
  /// `<c:title>` (CT_Title). Optional. Captured verbatim until typed.
  title : @xml.XmlElement?
  /// `<c:autoTitleDeleted val="…"/>`. Optional Bool.
  auto_title_deleted : Bool?
  /// `<c:pivotFmts>` (CT_PivotFmts). Optional. Captured verbatim.
  pivot_fmts : @xml.XmlElement?
  /// `<c:view3D>` (CT_View3D). Optional. Captured verbatim — only
  /// emitted by 3-D chart variants.
  view3d : @xml.XmlElement?
  /// `<c:floor>` (CT_Surface). Optional. Captured verbatim (3-D).
  floor : @xml.XmlElement?
  /// `<c:sideWall>` (CT_Surface). Optional. Captured verbatim (3-D).
  side_wall : @xml.XmlElement?
  /// `<c:backWall>` (CT_Surface). Optional. Captured verbatim (3-D).
  back_wall : @xml.XmlElement?
  /// `<c:plotArea>` (CT_PlotArea). REQUIRED. The structural skeleton
  /// is typed; axis bodies and currently-untyped plot kinds stay as
  /// captured `XmlElement` payloads inside their respective enums.
  plot_area : PlotArea
  /// `<c:legend>` (CT_Legend). Optional. Captured verbatim until typed.
  legend : @xml.XmlElement?
  /// `<c:plotVisOnly val="…"/>` — show only data on visible cells.
  plot_vis_only : Bool?
  /// `<c:dispBlanksAs val="…"/>` — how to render gaps. Three-value
  /// enum: `span` / `gap` / `zero`.
  disp_blanks_as : DisplayBlanksAs?
  /// `<c:showDLblsOverMax val="…"/>` — show data labels past chart
  /// scale max.
  show_d_lbls_over_max : Bool?
  /// `<c:chart>`-level unmodelled children (`<c:extLst>`,
  /// foreign-namespace).
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartBody with fn output(self, logger) {
  logger.write_string("ChartBody { … }")
  let _ = self
}

///|
/// `<c:dispBlanksAs val="…"/>` (CT_DispBlanksAs). How blank cells in
/// the source range render on the chart.
pub(all) enum DisplayBlanksAs {
  /// `val="span"` — interpolate across the gap.
  Span
  /// `val="gap"` — leave the gap visible (default).
  Gap
  /// `val="zero"` — treat blank as zero.
  Zero
} derive(Eq, Debug)

///|
pub impl Show for DisplayBlanksAs with fn output(self, logger) {
  match self {
    Span => logger.write_string("Span")
    Gap => logger.write_string("Gap")
    Zero => logger.write_string("Zero")
  }
}

///|
/// Parse `<c:dispBlanksAs val>` token into the enum. Returns `None`
/// for an unknown token so the caller can decide whether to ignore
/// or raise. Currently callers ignore — schema requires the value
/// but we'd rather round-trip the rest of the chart than reject on
/// a schema violation in one leaf.
pub fn DisplayBlanksAs::from_xml(s : String) -> DisplayBlanksAs? {
  match s {
    "span" => Some(Span)
    "gap" => Some(Gap)
    "zero" => Some(Zero)
    _ => None
  }
}

///|
/// Inverse of `from_xml`.
pub fn DisplayBlanksAs::to_xml(self : DisplayBlanksAs) -> String {
  match self {
    Span => "span"
    Gap => "gap"
    Zero => "zero"
  }
}

// --- PlotArea ---

///|
/// `<c:plotArea>` body (ECMA-376 §21.2.2.14, `CT_PlotArea`).
///
/// The plot area is where the actual chart content lives. Element
/// order (per the schema):
///
///   <c:layout>        (optional)
///   one or more plot-type children — see `Plot` enum
///   one or more axes — see `Axis` enum
///   <c:dTable>        (optional)
///   <c:spPr>          (optional)
///   <c:extLst>        (optional)
///
/// `plots : Array[Plot]` and `axes : Array[Axis]` carry one variant
/// per modelled element kind. Each variant either wraps a typed body
/// (where the chart family has been lifted) or the captured
/// `<XmlElement>` so the content round-trips losslessly. Untyped
/// variants are migrated to typed bodies incrementally.
pub(all) struct PlotArea {
  /// `<c:layout>` (CT_Layout). Captured verbatim — typed later.
  layout : @xml.XmlElement?
  /// Plot-type children in source order. PowerPoint combination
  /// charts can carry multiple — e.g. a `barChart` overlaid on a
  /// `lineChart` — so this is an array, not an `Option`.
  plots : Array[Plot]
  /// Axes in source order. Charts typically carry two (catAx +
  /// valAx, or two valAx for scatter / bubble), but a deck can
  /// encode any combination.
  axes : Array[Axis]
  /// `<c:dTable>` (CT_DTable). Captured verbatim — typed later.
  data_table : @xml.XmlElement?
  /// `<c:spPr>` shape-properties for the plot-area background.
  /// Captured verbatim — typed later when the plot-area styling
  /// builder lands.
  sp_pr : @xml.XmlElement?
  /// Unmodelled children (`<c:extLst>`, foreign-namespace). ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for PlotArea with fn output(self, logger) {
  logger.write_string("PlotArea { … }")
  let _ = self
}

///|
/// Discriminated chart-plot kinds — the choice element inside
/// `<c:plotArea>`. Names every spec'd kind. Variants whose body has
/// been typed carry a `<Family>ChartBody` value; the remaining
/// variants wrap the captured `<XmlElement>` so the body round-trips
/// losslessly until typed.
pub(all) enum Plot {
  /// `<c:areaChart>` — typed body.
  AreaChart(AreaChartBody)
  /// `<c:area3DChart>` — typed body.
  Area3DChart(Area3DChartBody)
  /// `<c:lineChart>` — typed body.
  LineChart(LineChartBody)
  /// `<c:line3DChart>` — typed body.
  Line3DChart(Line3DChartBody)
  /// `<c:stockChart>` — typed body.
  StockChart(StockChartBody)
  /// `<c:radarChart>` — typed body.
  RadarChart(RadarChartBody)
  /// `<c:scatterChart>` — typed body.
  ScatterChart(ScatterChartBody)
  /// `<c:pieChart>` — typed body.
  PieChart(PieChartBody)
  /// `<c:pie3DChart>` — typed body.
  Pie3DChart(Pie3DChartBody)
  /// `<c:doughnutChart>` — typed body.
  DoughnutChart(DoughnutChartBody)
  /// `<c:barChart>` — typed body.
  BarChart(BarChartBody)
  /// `<c:bar3DChart>` — typed body.
  Bar3DChart(Bar3DChartBody)
  /// `<c:ofPieChart>` — typed body.
  OfPieChart(OfPieChartBody)
  /// `<c:surfaceChart>` — typed body.
  SurfaceChart(SurfaceChartBody)
  /// `<c:surface3DChart>` — typed body.
  Surface3DChart(Surface3DChartBody)
  /// `<c:bubbleChart>` — typed body.
  BubbleChart(BubbleChartBody)
} derive(Eq, Debug)

///|
pub impl Show for Plot with fn output(self, logger) {
  logger.write_string("Plot(")
  logger.write_string(self.local_name())
  logger.write_string(")")
}

///|
/// Local-name as it appears in the chart XML. Useful for diagnostic
/// output and writer dispatch.
pub fn Plot::local_name(self : Plot) -> String {
  match self {
    AreaChart(_) => "areaChart"
    Area3DChart(_) => "area3DChart"
    LineChart(_) => "lineChart"
    Line3DChart(_) => "line3DChart"
    StockChart(_) => "stockChart"
    RadarChart(_) => "radarChart"
    ScatterChart(_) => "scatterChart"
    PieChart(_) => "pieChart"
    Pie3DChart(_) => "pie3DChart"
    DoughnutChart(_) => "doughnutChart"
    BarChart(_) => "barChart"
    Bar3DChart(_) => "bar3DChart"
    OfPieChart(_) => "ofPieChart"
    SurfaceChart(_) => "surfaceChart"
    Surface3DChart(_) => "surface3DChart"
    BubbleChart(_) => "bubbleChart"
  }
}

///|
/// Discriminated axis kinds inside `<c:plotArea>`. Same wholesale-
/// capture-with-named-variant pattern as `Plot`.
pub(all) enum Axis {
  /// `<c:valAx>` (CT_ValAx) — value axis.
  ValAx(@xml.XmlElement)
  /// `<c:catAx>` (CT_CatAx) — category axis.
  CatAx(@xml.XmlElement)
  /// `<c:dateAx>` (CT_DateAx) — date axis.
  DateAx(@xml.XmlElement)
  /// `<c:serAx>` (CT_SerAx) — series axis.
  SerAx(@xml.XmlElement)
} derive(Eq, Debug)

///|
pub impl Show for Axis with fn output(self, logger) {
  logger.write_string("Axis(")
  logger.write_string(self.local_name())
  logger.write_string(")")
}

///|
pub fn Axis::local_name(self : Axis) -> String {
  match self {
    ValAx(_) => "valAx"
    CatAx(_) => "catAx"
    DateAx(_) => "dateAx"
    SerAx(_) => "serAx"
  }
}

///|
pub fn Axis::element(self : Axis) -> @xml.XmlElement {
  match self {
    ValAx(e) | CatAx(e) | DateAx(e) | SerAx(e) => e
  }
}
