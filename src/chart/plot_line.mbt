// Line-chart family.
//
// `<c:lineChart>` (ECMA-376 §21.2.2.97, `CT_LineChart`). Schema:
//
//   <c:grouping>    (REQUIRED, CT_Grouping — standard|stacked|percentStacked)
//   <c:varyColors>  (optional Bool)
//   <c:ser>*        (zero or more series — CT_LineSer)
//   <c:dLbls>       (optional)
//   <c:dropLines>   (optional)
//   <c:hiLowLines>  (optional)
//   <c:upDownBars>  (optional)
//   <c:marker>      (optional Bool)
//   <c:smooth>      (optional Bool)
//   <c:axId>{2}     (REQUIRED — exactly two)
//   <c:extLst>      (optional)
//
// The substantial subtrees (`<c:ser>`, `<c:dLbls>`, the three
// line-decoration elements) stay as captured `XmlElement?` payloads.

///|
/// Typed `<c:lineChart>` body.
///
/// - `grouping` (`<c:grouping>`) — REQUIRED. Three-value enum shared with the
///   area-chart family (CT_Grouping).
/// - `vary_colors` (`<c:varyColors>`) — optional bool.
/// - `series` — `<c:ser>` series in source order — captured `<XmlElement>`.
/// - `d_lbls` (`<c:dLbls>`) — optional. Captured verbatim.
/// - `drop_lines` — `<c:dropLines>` (CT_ChartLines) — optional. Vertical drop
///   indicators on the chart. Captured verbatim.
/// - `hi_low_lines` — `<c:hiLowLines>` (CT_ChartLines) — optional. Captured
///   verbatim.
/// - `up_down_bars` — `<c:upDownBars>` (CT_UpDownBars) — optional. Captured
///   verbatim.
/// - `marker` (`<c:marker>`) — optional bool. Whether series markers are
///   rendered.
/// - `smooth` (`<c:smooth>`) — optional bool. Whether the line is smoothed.
/// - `ax_ids` — `<c:axId>` references — REQUIRED, exactly two per schema.
pub(all) struct LineChartBody {
  grouping : Grouping
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  drop_lines : @xml.XmlElement?
  hi_low_lines : @xml.XmlElement?
  up_down_bars : @xml.XmlElement?
  marker : Bool?
  smooth : Bool?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for LineChartBody with fn output(self, logger) {
  logger.write_string("LineChartBody(")
  logger.write_string(self.grouping.to_xml())
  logger.write_string(", ")
  logger.write_string(self.ax_ids.length().to_string())
  logger.write_string(" axIds, ")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// `CT_Grouping` — shared by `<c:lineChart>`, `<c:areaChart>`, and
/// `<c:line3DChart>` / `<c:area3DChart>`. Three values, distinct
/// from the bar family's four-value `BarGrouping`.
///
/// - `Standard` — `val="standard"`
/// - `Stacked` — `val="stacked"`
/// - `PercentStacked` — `val="percentStacked"`
pub(all) enum Grouping {
  Standard
  Stacked
  PercentStacked
} derive(Eq, Debug)

///|
pub impl Show for Grouping with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `Grouping` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn Grouping::from_xml(s : String) -> Grouping? {
  match s {
    "standard" => Some(Standard)
    "stacked" => Some(Stacked)
    "percentStacked" => Some(PercentStacked)
    _ => None
  }
}

///|
/// Serialise `Grouping` back to the OOXML attribute string.
pub fn Grouping::to_xml(self : Grouping) -> String {
  match self {
    Standard => "standard"
    Stacked => "stacked"
    PercentStacked => "percentStacked"
  }
}
