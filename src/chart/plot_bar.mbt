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
pub(all) struct BarChartBody {
  /// `<c:barDir>` — REQUIRED. `bar` for horizontal, `col` for
  /// vertical (the schema's two values).
  bar_dir : BarDir
  /// `<c:grouping>` — optional. Four-value enum.
  grouping : BarGrouping?
  /// `<c:varyColors>` — optional bool.
  vary_colors : Bool?
  /// `<c:ser>` — zero or more series in source order. Captured
  /// verbatim; typed (CT_BarSer body) by a later 7a slice.
  series : Array[@xml.XmlElement]
  /// `<c:dLbls>` — optional data labels. Captured verbatim.
  d_lbls : @xml.XmlElement?
  /// `<c:gapWidth val="…"/>` — percentage; integer in the source.
  /// 0..500 per schema.
  gap_width : Int?
  /// `<c:overlap val="…"/>` — signed percentage, -100..100.
  overlap : Int?
  /// `<c:axId val="…"/>` — REQUIRED. 2-D bar charts emit two,
  /// 3-D bar charts (bar3DChart, not here) emit three. Surfaced
  /// as `Array[Int]` rather than fixed-length so future schema
  /// loosening / strict validation can be added later.
  ax_ids : Array[Int]
  /// `<c:extLst>` plus any foreign-namespace siblings.
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
pub(all) enum BarDir {
  /// `val="bar"` — horizontal bars.
  Bar
  /// `val="col"` — vertical columns (the default for new charts).
  Col
} derive(Eq, Debug)

///|
pub impl Show for BarDir with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
pub fn BarDir::from_xml(s : String) -> BarDir? {
  match s {
    "bar" => Some(Bar)
    "col" => Some(Col)
    _ => None
  }
}

///|
pub fn BarDir::to_xml(self : BarDir) -> String {
  match self {
    Bar => "bar"
    Col => "col"
  }
}

///|
/// `<c:grouping val="…"/>` (CT_BarGrouping). Four-value enum.
pub(all) enum BarGrouping {
  /// `val="percentStacked"`
  PercentStacked
  /// `val="clustered"` — bars side by side (the default).
  Clustered
  /// `val="standard"`
  Standard
  /// `val="stacked"`
  Stacked
} derive(Eq, Debug)

///|
pub impl Show for BarGrouping with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
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
pub fn BarGrouping::to_xml(self : BarGrouping) -> String {
  match self {
    PercentStacked => "percentStacked"
    Clustered => "clustered"
    Standard => "standard"
    Stacked => "stacked"
  }
}
