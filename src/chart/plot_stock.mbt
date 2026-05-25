// Stock-chart family.
//
// `<c:stockChart>` (ECMA-376 §21.2.2.176, `CT_StockChart`):
//
//   <c:ser>{3,4}    (REQUIRED — three series for HLC,
//                    four for OHLC)
//   <c:dLbls>       (optional)
//   <c:dropLines>   (optional)
//   <c:hiLowLines>  (optional)
//   <c:upDownBars>  (optional)
//   <c:axId>{2}     (REQUIRED — category + value)
//   <c:extLst>      (optional)
//
// Stock charts are specialised: the series count discriminates
// between high-low-close (3) and open-high-low-close (4). The
// schema doesn't surface this discriminator as an enum — it's
// derived from `series.length()`.

///|
pub(all) struct StockChartBody {
  /// `<c:ser>` — three for HLC charts, four for OHLC. Captured
  /// XmlElement payloads.
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  drop_lines : @xml.XmlElement?
  hi_low_lines : @xml.XmlElement?
  up_down_bars : @xml.XmlElement?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for StockChartBody with fn output(self, logger) {
  logger.write_string("StockChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}
