// Scatter-chart family.
//
// `<c:scatterChart>` (ECMA-376 §21.2.2.161, `CT_ScatterChart`):
//
//   <c:scatterStyle> (REQUIRED, CT_ScatterStyle —
//                     line|lineMarker|marker|none|smooth|smoothMarker)
//   <c:varyColors>   (optional Bool)
//   <c:ser>*         (zero or more series — CT_ScatterSer)
//   <c:dLbls>        (optional)
//   <c:axId>{2}      (REQUIRED — two value axes)
//   <c:extLst>       (optional)
//
// Scatter charts use two value axes (`<c:valAx>` × 2), distinct from
// the category-axis + value-axis pair every other 2-D chart uses.

///|
pub(all) struct ScatterChartBody {
  scatter_style : ScatterStyle
  vary_colors : Bool?
  series : Array[ScatterSeriesCore]
  d_lbls : @xml.XmlElement?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ScatterChartBody with fn output(self, logger) {
  logger.write_string("ScatterChartBody(")
  logger.write_string(self.scatter_style.to_xml())
  logger.write_string(")")
}

///|
/// `<c:scatterStyle val="…"/>` (CT_ScatterStyle). Six-value enum.
pub(all) enum ScatterStyle {
  /// `val="line"` — connecting lines, no markers.
  Line
  /// `val="lineMarker"` — connecting lines plus markers.
  LineMarker
  /// `val="marker"` — markers only.
  Marker
  /// `val="none"` — neither lines nor markers (rare).
  None_
  /// `val="smooth"` — smoothed connecting lines.
  Smooth
  /// `val="smoothMarker"` — smoothed lines plus markers.
  SmoothMarker
} derive(Eq, Debug)

///|
pub impl Show for ScatterStyle with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
pub fn ScatterStyle::from_xml(s : String) -> ScatterStyle? {
  match s {
    "line" => Some(Line)
    "lineMarker" => Some(LineMarker)
    "marker" => Some(Marker)
    "none" => Some(None_)
    "smooth" => Some(Smooth)
    "smoothMarker" => Some(SmoothMarker)
    _ => None
  }
}

///|
pub fn ScatterStyle::to_xml(self : ScatterStyle) -> String {
  match self {
    Line => "line"
    LineMarker => "lineMarker"
    Marker => "marker"
    None_ => "none"
    Smooth => "smooth"
    SmoothMarker => "smoothMarker"
  }
}
