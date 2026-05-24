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
pub(all) struct LineChartBody {
  /// `<c:grouping>` — REQUIRED. Three-value enum shared with the
  /// area-chart family (CT_Grouping).
  grouping : Grouping
  /// `<c:varyColors>` — optional bool.
  vary_colors : Bool?
  /// `<c:ser>` series in source order — captured `<XmlElement>`.
  series : Array[@xml.XmlElement]
  /// `<c:dLbls>` — optional. Captured verbatim.
  d_lbls : @xml.XmlElement?
  /// `<c:dropLines>` (CT_ChartLines) — optional. Vertical drop
  /// indicators on the chart. Captured verbatim.
  drop_lines : @xml.XmlElement?
  /// `<c:hiLowLines>` (CT_ChartLines) — optional. Captured verbatim.
  hi_low_lines : @xml.XmlElement?
  /// `<c:upDownBars>` (CT_UpDownBars) — optional. Captured verbatim.
  up_down_bars : @xml.XmlElement?
  /// `<c:marker>` — optional bool. Whether series markers are
  /// rendered.
  marker : Bool?
  /// `<c:smooth>` — optional bool. Whether the line is smoothed.
  smooth : Bool?
  /// `<c:axId>` references — REQUIRED, exactly two per schema.
  ax_ids : Array[Int]
  /// ADR-004 tail.
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
pub(all) enum Grouping {
  /// `val="standard"`
  Standard
  /// `val="stacked"`
  Stacked
  /// `val="percentStacked"`
  PercentStacked
} derive(Eq, Debug)

///|
pub impl Show for Grouping with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
pub fn Grouping::from_xml(s : String) -> Grouping? {
  match s {
    "standard" => Some(Standard)
    "stacked" => Some(Stacked)
    "percentStacked" => Some(PercentStacked)
    _ => None
  }
}

///|
pub fn Grouping::to_xml(self : Grouping) -> String {
  match self {
    Standard => "standard"
    Stacked => "stacked"
    PercentStacked => "percentStacked"
  }
}
