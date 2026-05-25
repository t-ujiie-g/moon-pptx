// Of-pie chart family — pie-of-pie or bar-of-pie.
//
// `<c:ofPieChart>` (ECMA-376 §21.2.2.126, `CT_OfPieChart`):
//
//   <c:ofPieType>      (REQUIRED, CT_OfPieType — pie|bar)
//   <c:varyColors>     (optional Bool)
//   <c:ser>*           (zero or more series — CT_PieSer)
//   <c:dLbls>          (optional)
//   <c:gapWidth>       (optional, percentage 0..500)
//   <c:splitType>      (optional, enum CT_SplitType —
//                       auto|cust|percent|pos|val)
//   <c:splitPos>       (optional, Double — the split position
//                       under cust/percent/pos/val)
//   <c:custSplit>      (optional — explicit per-slice routing)
//   <c:secondPieSize>  (optional, percentage 5..200)
//   <c:serLines>*      (optional — series-line formatting)
//   <c:extLst>         (optional)
//
// Used for the "pie-of-pie" or "bar-of-pie" variants where the
// smallest pie slices are exploded into a secondary pie or bar.

///|
/// Body of `<c:ofPieChart>` (CT_OfPieChart). Pie-of-pie or
/// bar-of-pie charts split the smallest slices into a
/// secondary plot.
pub(all) struct OfPieChartBody {
  of_pie_type : OfPieType
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  gap_width : Int?
  split_type : SplitType?
  /// `<c:splitPos val="…"/>` — schema-typed as Double; kept as the
  /// raw string here so the source representation round-trips
  /// without floating-point format drift. Meaning depends on
  /// `split_type`: position threshold under `Pos`, value threshold
  /// under `Val`, percentage threshold under `Percent`, slice index
  /// list under `Cust` (then `custSplit` carries the actual list).
  split_pos : String?
  /// `<c:custSplit>` — explicit per-slice routing list. Captured
  /// XmlElement.
  cust_split : @xml.XmlElement?
  /// `<c:secondPieSize val="…"/>` — integer percentage 5..200.
  second_pie_size : Int?
  /// `<c:serLines>` — series-line formatting overrides. Zero or
  /// more in the schema; captured XmlElement payloads.
  ser_lines : Array[@xml.XmlElement]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for OfPieChartBody with fn output(self, logger) {
  logger.write_string("OfPieChartBody(")
  logger.write_string(self.of_pie_type.to_xml())
  logger.write_string(")")
}

///|
/// `<c:ofPieType val="…"/>` (CT_OfPieType). Two-value enum.
pub(all) enum OfPieType {
  /// `val="pie"` — secondary chart is a pie.
  Pie
  /// `val="bar"` — secondary chart is a bar.
  Bar
} derive(Eq, Debug)

///|
pub impl Show for OfPieType with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `OfPieType` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn OfPieType::from_xml(s : String) -> OfPieType? {
  match s {
    "pie" => Some(Pie)
    "bar" => Some(Bar)
    _ => None
  }
}

///|
/// Serialise `OfPieType` back to the OOXML attribute string.
pub fn OfPieType::to_xml(self : OfPieType) -> String {
  match self {
    Pie => "pie"
    Bar => "bar"
  }
}

///|
/// `<c:splitType val="…"/>` (CT_SplitType). Five-value enum
/// controlling how primary-pie slices route into the secondary
/// chart.
pub(all) enum SplitType {
  /// `val="auto"` — automatic split (the default).
  Auto
  /// `val="cust"` — custom split per slice (see `<c:custSplit>`).
  Cust
  /// `val="percent"` — slices below a percentage threshold move.
  Percent
  /// `val="pos"` — last N slices (by position) move.
  Pos
  /// `val="val"` — slices below a value threshold move.
  Val
} derive(Eq, Debug)

///|
pub impl Show for SplitType with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `SplitType` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn SplitType::from_xml(s : String) -> SplitType? {
  match s {
    "auto" => Some(Auto)
    "cust" => Some(Cust)
    "percent" => Some(Percent)
    "pos" => Some(Pos)
    "val" => Some(Val)
    _ => None
  }
}

///|
/// Serialise `SplitType` back to the OOXML attribute string.
pub fn SplitType::to_xml(self : SplitType) -> String {
  match self {
    Auto => "auto"
    Cust => "cust"
    Percent => "percent"
    Pos => "pos"
    Val => "val"
  }
}
