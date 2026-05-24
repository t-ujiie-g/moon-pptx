// Bubble-chart family.
//
// `<c:bubbleChart>` (ECMA-376 §21.2.2.20, `CT_BubbleChart`):
//
//   <c:varyColors>     (optional Bool)
//   <c:ser>*           (zero or more series — CT_BubbleSer)
//   <c:dLbls>          (optional)
//   <c:bubble3D>       (optional Bool — render bubbles with 3-D effect)
//   <c:bubbleScale>    (optional, 0..300 percentage)
//   <c:showNegBubbles> (optional Bool)
//   <c:sizeRepresents> (optional, enum area|w)
//   <c:axId>{2}        (REQUIRED — two value axes)
//   <c:extLst>         (optional)

///|
pub(all) struct BubbleChartBody {
  vary_colors : Bool?
  series : Array[BubbleSeriesCore]
  d_lbls : @xml.XmlElement?
  bubble_3d : Bool?
  /// `<c:bubbleScale val="…"/>` — integer percentage 0..300.
  bubble_scale : Int?
  /// `<c:showNegBubbles val="…"/>` — whether to render bubbles for
  /// negative size values.
  show_neg_bubbles : Bool?
  /// `<c:sizeRepresents val="…"/>` — how the numeric size maps to
  /// the bubble's drawn dimension (`area` or `w`idth).
  size_represents : SizeRepresents?
  ax_ids : Array[Int]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for BubbleChartBody with fn output(self, logger) {
  logger.write_string("BubbleChartBody(")
  logger.write_string(self.series.length().to_string())
  logger.write_string(" series)")
}

///|
/// `<c:sizeRepresents val="…"/>` (CT_SizeRepresents). Two-value enum.
pub(all) enum SizeRepresents {
  /// `val="area"` — bubble area is proportional to the size value
  /// (the default).
  Area
  /// `val="w"` — bubble width (diameter) is proportional to size.
  Width
} derive(Eq, Debug)

///|
pub impl Show for SizeRepresents with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
pub fn SizeRepresents::from_xml(s : String) -> SizeRepresents? {
  match s {
    "area" => Some(Area)
    "w" => Some(Width)
    _ => None
  }
}

///|
pub fn SizeRepresents::to_xml(self : SizeRepresents) -> String {
  match self {
    Area => "area"
    Width => "w"
  }
}
