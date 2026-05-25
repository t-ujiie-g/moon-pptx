// Area-chart family (2-D + 3-D).
//
// `<c:areaChart>` (ECMA-376 §21.2.2.3, `CT_AreaChart`):
//   grouping (CT_Grouping)? — note: optional in this family
//   varyColors?  ser*  dLbls?  dropLines?  axId{2,3}  extLst?
//
// `<c:area3DChart>` (§21.2.2.4, `CT_Area3DChart`):
//   adds `gapDepth?` between dropLines and axId{2,3}.
//
// Same `Grouping` enum (CT_Grouping) shared with line.

///|
/// Body of `<c:areaChart>` (CT_AreaChart).
pub(all) struct AreaChartBody {
  grouping : Grouping?
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  drop_lines : @xml.XmlElement?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for AreaChartBody with fn output(self, logger) {
  logger.write_string("AreaChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// Body of `<c:area3DChart>` (CT_Area3DChart). 3-D area charts
/// add a series-axis (third `axId`) plus an optional `gapDepth`.
pub(all) struct Area3DChartBody {
  grouping : Grouping?
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  drop_lines : @xml.XmlElement?
  /// `<c:gapDepth val="…"/>` — depth of the gap between data
  /// series along the depth axis as a percentage of bar width.
  gap_depth : Int?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Area3DChartBody with fn output(self, logger) {
  logger.write_string("Area3DChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}
