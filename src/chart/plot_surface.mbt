// Surface-chart family (2-D + 3-D).
//
// `<c:surfaceChart>` (ECMA-376 §21.2.2.181, `CT_SurfaceChart`):
//
//   <c:wireframe>  (optional Bool)
//   <c:ser>*       (zero or more series — CT_SurfaceSer)
//   <c:bandFmts>   (optional)
//   <c:axId>{2,3}  (REQUIRED — two or three depending on view)
//   <c:extLst>     (optional)
//
// `<c:surface3DChart>` (§21.2.2.182, `CT_Surface3DChart`): same
// schema but `axId{3}` and a different element name. We type
// them with separate bodies so the writer's element-name
// dispatch stays mechanical.

///|
/// Body of `<c:surfaceChart>` (CT_SurfaceChart).
pub(all) struct SurfaceChartBody {
  wireframe : Bool?
  series : Array[ChartSeriesCore]
  /// `<c:bandFmts>` (CT_BandFmts) — band formatting overrides.
  /// Captured XmlElement.
  band_fmts : @xml.XmlElement?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for SurfaceChartBody with fn output(self, logger) {
  logger.write_string("SurfaceChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// Body of `<c:surface3DChart>` (CT_Surface3DChart).
pub(all) struct Surface3DChartBody {
  wireframe : Bool?
  series : Array[ChartSeriesCore]
  band_fmts : @xml.XmlElement?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Surface3DChartBody with fn output(self, logger) {
  logger.write_string("Surface3DChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}
