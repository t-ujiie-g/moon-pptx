// 3-D variants of bar / line / pie.
//
// `<c:bar3DChart>` (CT_Bar3DChart §21.2.2.15):
//   barDir REQUIRED ; grouping (BarGrouping)? ; varyColors? ; ser* ;
//   dLbls? ; gapWidth? ; gapDepth? ; shape? ; axId{3} ; extLst?
//
// `<c:line3DChart>` (CT_Line3DChart §21.2.2.96):
//   grouping REQUIRED ; varyColors? ; ser* ; dLbls? ; dropLines? ;
//   gapDepth? ; axId{3} ; extLst?
//
// `<c:pie3DChart>` (CT_Pie3DChart §21.2.2.140):
//   varyColors? ; ser* ; dLbls? ; extLst?
//   (no `firstSliceAng` — that's 2-D pie only)

///|
/// Body of `<c:bar3DChart>` (CT_Bar3DChart).
pub(all) struct Bar3DChartBody {
  bar_dir : BarDir
  grouping : BarGrouping?
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  gap_width : Int?
  gap_depth : Int?
  /// `<c:shape val="…"/>` — bar shape. Optional per schema.
  shape : BarShape?
  /// Three axIds for 3D charts (category / value / series axis).
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Bar3DChartBody with fn output(self, logger) {
  logger.write_string("Bar3DChartBody(")
  logger.write_string(self.bar_dir.to_xml())
  logger.write_string(")")
}

///|
/// Body of `<c:line3DChart>` (CT_Line3DChart).
pub(all) struct Line3DChartBody {
  grouping : Grouping
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  drop_lines : @xml.XmlElement?
  gap_depth : Int?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Line3DChartBody with fn output(self, logger) {
  logger.write_string("Line3DChartBody(")
  logger.write_string(self.grouping.to_xml())
  logger.write_string(")")
}

///|
/// Body of `<c:pie3DChart>` (CT_Pie3DChart). Pie 3-D charts have
/// no axes.
pub(all) struct Pie3DChartBody {
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : DLbls?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Pie3DChartBody with fn output(self, logger) {
  logger.write_string("Pie3DChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// `<c:shape val="…"/>` (CT_Shape). Six-value enum used by 3-D bar
/// charts to choose the bar silhouette.
pub(all) enum BarShape {
  /// `val="box"` — rectangular bars (default).
  Box
  /// `val="cone"` — full conical bars.
  Cone
  /// `val="coneToMax"` — conical bars tapering to the maximum height.
  ConeToMax
  /// `val="cylinder"`
  Cylinder
  /// `val="pyramid"`
  Pyramid
  /// `val="pyramidToMax"`
  PyramidToMax
} derive(Eq, Debug)

///|
pub impl Show for BarShape with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `BarShape` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn BarShape::from_xml(s : String) -> BarShape? {
  match s {
    "box" => Some(Box)
    "cone" => Some(Cone)
    "coneToMax" => Some(ConeToMax)
    "cylinder" => Some(Cylinder)
    "pyramid" => Some(Pyramid)
    "pyramidToMax" => Some(PyramidToMax)
    _ => None
  }
}

///|
/// Serialise `BarShape` back to the OOXML attribute string.
pub fn BarShape::to_xml(self : BarShape) -> String {
  match self {
    Box => "box"
    Cone => "cone"
    ConeToMax => "coneToMax"
    Cylinder => "cylinder"
    Pyramid => "pyramid"
    PyramidToMax => "pyramidToMax"
  }
}
