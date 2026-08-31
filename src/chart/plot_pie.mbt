// Pie-chart family.
//
// `<c:pieChart>` (ECMA-376 §21.2.2.141, `CT_PieChart`). Schema:
//
//   <c:varyColors>    (optional Bool)
//   <c:ser>*          (zero or more series — CT_PieSer)
//   <c:dLbls>         (optional)
//   <c:firstSliceAng> (optional, integer 0..360 degrees)
//   <c:extLst>        (optional)
//
// Pie charts have no axes (unlike bar / line / scatter), so the
// body is the simplest of the typed families. Series and data
// labels stay captured as `XmlElement` until their own typing.

///|
/// Typed `<c:pieChart>` body.
///
/// - `vary_colors` (`<c:varyColors>`) — optional. Pie charts almost always
///   emit `val="1"` because slice-by-slice colouring is the visual point.
/// - `series` — `<c:ser>` series — usually one for pie charts. Captured
///   `<XmlElement>`.
/// - `d_lbls` (`<c:dLbls>`) — optional data labels. Captured verbatim.
/// - `first_slice_ang` (`<c:firstSliceAng val="…"/>`) — integer degrees
///   0..360 for the starting position of the first slice. `0` (top) is the
///   default.
pub(all) struct PieChartBody {
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  first_slice_ang : Int?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for PieChartBody with fn output(self, logger) {
  logger.write_string("PieChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}
