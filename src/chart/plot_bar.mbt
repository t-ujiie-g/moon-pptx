// Bar-chart family.
//
// `<c:barChart>` (ECMA-376 §21.2.2.16, `CT_BarChart`) — vertical or
// horizontal bar/column charts, optionally stacked. Schema:
//
//   <c:barDir>     (REQUIRED, enum bar|col)
//   <c:grouping>   (optional, enum percentStacked|clustered|standard|stacked)
//   <c:varyColors> (optional Bool)
//   <c:ser>*       (zero or more series — CT_BarSer)
//   <c:dLbls>      (optional)
//   <c:gapWidth>   (optional, percentage as integer 0..500)
//   <c:overlap>    (optional, signed percentage -100..100)
//   <c:axId>{2,3}  (REQUIRED — two for 2-D charts, three for 3-D)
//   <c:extLst>     (optional)
//
// `<c:ser>` (CT_BarSer) and `<c:dLbls>` are still captured as
// `XmlElement` payloads — they have substantial typed bodies that
// will lift in their own slices.

///|
/// Typed `<c:barChart>` body.
///
/// - `bar_dir` (`<c:barDir>`) — REQUIRED. `bar` for horizontal, `col` for
///   vertical (the schema's two values).
/// - `grouping` (`<c:grouping>`) — optional. Four-value enum.
/// - `vary_colors` (`<c:varyColors>`) — optional bool.
/// - `series` (`<c:ser>`) — zero or more series in source order. Captured
///   verbatim; typed (CT_BarSer body) by a later 7a slice.
/// - `d_lbls` (`<c:dLbls>`) — optional data labels. Captured verbatim.
/// - `gap_width` (`<c:gapWidth val="…"/>`) — percentage; integer in the
///   source. 0..500 per schema.
/// - `overlap` (`<c:overlap val="…"/>`) — signed percentage, -100..100.
/// - `ax_ids` (`<c:axId val="…"/>`) — REQUIRED. 2-D bar charts emit two, 3-D
///   bar charts (bar3DChart, not here) emit three. Surfaced as `Array[Int]`
///   rather than fixed-length so future schema loosening / strict validation
///   can be added later.
/// - `extension` — `<c:extLst>` plus any foreign-namespace siblings.
pub(all) struct BarChartBody {
  bar_dir : BarDir
  grouping : BarGrouping?
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  gap_width : Int?
  overlap : Int?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for BarChartBody with fn output(self, logger) {
  logger.write_string("BarChartBody(")
  logger.write_string(self.bar_dir.to_xml())
  logger.write_string(", ")
  logger.write_string(self.ax_ids.length().to_string())
  logger.write_string(" axIds, ")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// `<c:barDir val="…"/>` (CT_BarDir). Two-value enum.
///
/// - `Bar` (`val="bar"`) — horizontal bars.
/// - `Col` (`val="col"`) — vertical columns (the default for new charts).
pub(all) enum BarDir {
  Bar
  Col
} derive(Eq, Debug)

///|
pub impl Show for BarDir with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `BarDir` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn BarDir::from_xml(s : String) -> BarDir? {
  match s {
    "bar" => Some(Bar)
    "col" => Some(Col)
    _ => None
  }
}

///|
/// Serialise `BarDir` back to the OOXML attribute string.
pub fn BarDir::to_xml(self : BarDir) -> String {
  match self {
    Bar => "bar"
    Col => "col"
  }
}

///|
/// `<c:grouping val="…"/>` (CT_BarGrouping). Four-value enum.
///
/// - `PercentStacked` — `val="percentStacked"`
/// - `Clustered` (`val="clustered"`) — bars side by side (the default).
/// - `Standard` — `val="standard"`
/// - `Stacked` — `val="stacked"`
pub(all) enum BarGrouping {
  PercentStacked
  Clustered
  Standard
  Stacked
} derive(Eq, Debug)

///|
pub impl Show for BarGrouping with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `BarGrouping` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn BarGrouping::from_xml(s : String) -> BarGrouping? {
  match s {
    "percentStacked" => Some(PercentStacked)
    "clustered" => Some(Clustered)
    "standard" => Some(Standard)
    "stacked" => Some(Stacked)
    _ => None
  }
}

///|
/// Serialise `BarGrouping` back to the OOXML attribute string.
pub fn BarGrouping::to_xml(self : BarGrouping) -> String {
  match self {
    PercentStacked => "percentStacked"
    Clustered => "clustered"
    Standard => "standard"
    Stacked => "stacked"
  }
}
