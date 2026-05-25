// Doughnut-chart family.
//
// `<c:doughnutChart>` (ECMA-376 §21.2.2.50, `CT_DoughnutChart`):
//   varyColors?  ser*  dLbls?  firstSliceAng?  holeSize?  extLst?
//
// Same shape as pieChart with one extra leaf — `holeSize`, the
// interior gap diameter as a percentage of the outer diameter.

///|
/// Body of `<c:doughnutChart>` (CT_DoughnutChart). Like pie, but
/// with an inner radius (`holeSize`, 1–90 %).
pub(all) struct DoughnutChartBody {
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  /// `<c:firstSliceAng val="…"/>` — integer degrees 0..360.
  first_slice_ang : Int?
  /// `<c:holeSize val="…"/>` — integer percentage 10..90 in
  /// practice (schema says 1..90).
  hole_size : Int?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for DoughnutChartBody with fn output(self, logger) {
  logger.write_string("DoughnutChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}
