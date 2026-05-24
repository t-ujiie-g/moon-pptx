// Radar-chart family.
//
// `<c:radarChart>` (ECMA-376 §21.2.2.153, `CT_RadarChart`):
//   radarStyle (REQUIRED, enum) ; varyColors? ; ser* ; dLbls? ;
//   axId{2} ; extLst?

///|
pub(all) struct RadarChartBody {
  radar_style : RadarStyle
  vary_colors : Bool?
  series : Array[ChartSeriesCore]
  d_lbls : @xml.XmlElement?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for RadarChartBody with fn output(self, logger) {
  logger.write_string("RadarChartBody(")
  logger.write_string(self.radar_style.to_xml())
  logger.write_string(")")
}

///|
/// `<c:radarStyle val="…"/>` (CT_RadarStyle). Three-value enum.
pub(all) enum RadarStyle {
  /// `val="standard"` — unfilled lines connecting category points.
  Standard
  /// `val="marker"` — same as standard plus markers at points.
  Marker
  /// `val="filled"` — filled-area radar.
  Filled
} derive(Eq, Debug)

///|
pub impl Show for RadarStyle with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
pub fn RadarStyle::from_xml(s : String) -> RadarStyle? {
  match s {
    "standard" => Some(Standard)
    "marker" => Some(Marker)
    "filled" => Some(Filled)
    _ => None
  }
}

///|
pub fn RadarStyle::to_xml(self : RadarStyle) -> String {
  match self {
    Standard => "standard"
    Marker => "marker"
    Filled => "filled"
  }
}
