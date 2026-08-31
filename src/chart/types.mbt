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
///
/// - `date1904` (`<c:date1904>`) — workbook epoch flag. `None` when absent.
/// - `lang` (`<c:lang>`) — natural language identifier (e.g. `en-US`). `None`
///   when absent.
/// - `rounded_corners` (`<c:roundedCorners>`) — `None` when absent.
/// - `style` (`<c:style>`) — preset style index (1..48 in practice). `None`
///   when absent.
/// - `chart` (`<c:chart>`) — REQUIRED chart definition body.
pub(all) struct Chart {
  date1904 : Bool?
  lang : String?
  rounded_corners : Bool?
  style : Int?
  chart : ChartBody
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
///
/// - `title` — `<c:title>` (CT_Title) — typed body. Optional.
/// - `auto_title_deleted` — `<c:autoTitleDeleted val="…"/>`. Optional Bool.
/// - `pivot_fmts` — `<c:pivotFmts>` (CT_PivotFmts). Optional. Captured
///   verbatim.
/// - `view3d` — `<c:view3D>` (CT_View3D). Optional. Captured verbatim — only
///   emitted by 3-D chart variants.
/// - `floor` — `<c:floor>` (CT_Surface). Optional. Captured verbatim (3-D).
/// - `side_wall` — `<c:sideWall>` (CT_Surface). Optional. Captured verbatim
///   (3-D).
/// - `back_wall` — `<c:backWall>` (CT_Surface). Optional. Captured verbatim
///   (3-D).
/// - `plot_area` — `<c:plotArea>` (CT_PlotArea). REQUIRED. The structural
///   skeleton is typed; axis bodies and currently-untyped plot kinds stay as
///   captured `XmlElement` payloads inside their respective enums.
/// - `legend` — `<c:legend>` (CT_Legend) — typed body. Optional.
/// - `plot_vis_only` (`<c:plotVisOnly val="…"/>`) — show only data on visible
///   cells.
/// - `disp_blanks_as` (`<c:dispBlanksAs val="…"/>`) — how to render gaps.
///   Three-value enum: `span` / `gap` / `zero`.
/// - `show_d_lbls_over_max` (`<c:showDLblsOverMax val="…"/>`) — show data
///   labels past chart scale max.
/// - `extension` (`<c:chart>`) — level unmodelled children (`<c:extLst>`,
///   foreign-namespace).
pub(all) struct ChartBody {
  title : ChartTitle?
  auto_title_deleted : Bool?
  pivot_fmts : @xml.XmlElement?
  view3d : @xml.XmlElement?
  floor : @xml.XmlElement?
  side_wall : @xml.XmlElement?
  back_wall : @xml.XmlElement?
  plot_area : PlotArea
  legend : ChartLegend?
  plot_vis_only : Bool?
  disp_blanks_as : DisplayBlanksAs?
  show_d_lbls_over_max : Bool?
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
///
/// - `Span` (`val="span"`) — interpolate across the gap.
/// - `Gap` (`val="gap"`) — leave the gap visible (default).
/// - `Zero` (`val="zero"`) — treat blank as zero.
pub(all) enum DisplayBlanksAs {
  Span
  Gap
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
///
/// - `layout` — `<c:layout>` (CT_Layout) — typed body.
/// - `plots` — Plot-type children in source order. PowerPoint combination
///   charts can carry multiple — e.g. a `barChart` overlaid on a `lineChart`
///   — so this is an array, not an `Option`.
/// - `axes` — Axes in source order. Charts typically carry two (catAx +
///   valAx, or two valAx for scatter / bubble), but a deck can encode any
///   combination.
/// - `data_table` — `<c:dTable>` (CT_DTable). Captured verbatim — typed
///   later.
/// - `sp_pr` — `<c:spPr>` shape-properties for the plot-area background.
///   Captured verbatim — typed later when the plot-area styling builder
///   lands.
pub(all) struct PlotArea {
  layout : Layout?
  plots : Array[Plot]
  axes : Array[Axis]
  data_table : @xml.XmlElement?
  sp_pr : @xml.XmlElement?
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
///
/// - `AreaChart` (`<c:areaChart>`) — typed body.
/// - `Area3DChart` (`<c:area3DChart>`) — typed body.
/// - `LineChart` (`<c:lineChart>`) — typed body.
/// - `Line3DChart` (`<c:line3DChart>`) — typed body.
/// - `StockChart` (`<c:stockChart>`) — typed body.
/// - `RadarChart` (`<c:radarChart>`) — typed body.
/// - `ScatterChart` (`<c:scatterChart>`) — typed body.
/// - `PieChart` (`<c:pieChart>`) — typed body.
/// - `Pie3DChart` (`<c:pie3DChart>`) — typed body.
/// - `DoughnutChart` (`<c:doughnutChart>`) — typed body.
/// - `BarChart` (`<c:barChart>`) — typed body.
/// - `Bar3DChart` (`<c:bar3DChart>`) — typed body.
/// - `OfPieChart` (`<c:ofPieChart>`) — typed body.
/// - `SurfaceChart` (`<c:surfaceChart>`) — typed body.
/// - `Surface3DChart` (`<c:surface3DChart>`) — typed body.
/// - `BubbleChart` (`<c:bubbleChart>`) — typed body.
pub(all) enum Plot {
  AreaChart(AreaChartBody)
  Area3DChart(Area3DChartBody)
  LineChart(LineChartBody)
  Line3DChart(Line3DChartBody)
  StockChart(StockChartBody)
  RadarChart(RadarChartBody)
  ScatterChart(ScatterChartBody)
  PieChart(PieChartBody)
  Pie3DChart(Pie3DChartBody)
  DoughnutChart(DoughnutChartBody)
  BarChart(BarChartBody)
  Bar3DChart(Bar3DChartBody)
  OfPieChart(OfPieChartBody)
  SurfaceChart(SurfaceChartBody)
  Surface3DChart(Surface3DChartBody)
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
/// Discriminated axis kinds inside `<c:plotArea>`. Each variant wraps
/// a typed `AxisCore` (the shared CT_AxBase body). Per-axis-kind
/// extras (CatAx's `lblOffset`, ValAx's `crossBetween`, etc.) ride
/// on `AxisCore.extension` until later slices type them.
///
/// - `ValAx` — `<c:valAx>` (CT_ValAx) — value axis.
/// - `CatAx` — `<c:catAx>` (CT_CatAx) — category axis.
/// - `DateAx` — `<c:dateAx>` (CT_DateAx) — date axis.
/// - `SerAx` — `<c:serAx>` (CT_SerAx) — series axis.
pub(all) enum Axis {
  ValAx(AxisCore)
  CatAx(AxisCore)
  DateAx(AxisCore)
  SerAx(AxisCore)
} derive(Eq, Debug)

///|
pub impl Show for Axis with fn output(self, logger) {
  logger.write_string("Axis(")
  logger.write_string(self.local_name())
  logger.write_string(")")
}

///|
/// Local element name for this axis kind (`catAx` / `valAx` /
/// `dateAx` / `serAx`).
pub fn Axis::local_name(self : Axis) -> String {
  match self {
    ValAx(_) => "valAx"
    CatAx(_) => "catAx"
    DateAx(_) => "dateAx"
    SerAx(_) => "serAx"
  }
}

///|
/// Access the underlying `AxisCore` regardless of which variant.
pub fn Axis::core(self : Axis) -> AxisCore {
  match self {
    ValAx(c) | CatAx(c) | DateAx(c) | SerAx(c) => c
  }
}
