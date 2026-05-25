// Typed trendline body (CT_Trendline).
//
// `<c:trendline>` is a series-level child fitted curve overlay. Per
// ECMA-376 §21.2.2.211 (CT_Trendline):
//
//   <c:name>?           (xsd:string — display name, plain text)
//   <c:spPr>?           (CT_ShapeProperties)
//   <c:trendlineType>   (REQUIRED, ST_TrendlineType
//                        val=exp|linear|log|movingAvg|poly|power)
//   <c:order>?          (xsd:unsignedByte, default 2 — polynomial order)
//   <c:period>?         (xsd:unsignedInt, default 2 — moving-average period)
//   <c:forward>?        (CT_Double — forecast forward periods)
//   <c:backward>?       (CT_Double — forecast backward periods)
//   <c:intercept>?      (CT_Double — explicit Y-intercept)
//   <c:dispRSqr>?       (CT_Boolean — show R² value)
//   <c:dispEq>?         (CT_Boolean — show equation)
//   <c:trendlineLbl>?   (CT_TrendlineLbl — label styling)
//   <c:extLst>?
//
// Trendlines appear on every series-bearing chart family except pie /
// doughnut / radar / surface / surface3D / pie3D (where they make no
// sense). The typing here lives on every series-core flavour
// (`ChartSeriesCore`, `ScatterSeriesCore`, `BubbleSeriesCore`) — the
// pie-family parsers simply never push into the array.
//
// `<c:trendlineType>` is the only schema-required leaf. `<c:order>`
// and `<c:period>` have schema defaults (2) but we don't synthesise
// the default on parse — the field stays `None` so writers don't
// emit a redundant child. Floats (forward / backward / intercept)
// carry as `String?` to dodge format drift, matching the convention
// used elsewhere (Scaling.{max,min,log_base}, crossesAt, Layout.x/y/w/h).
//
// `<c:trendlineLbl>` (CT_TrendlineLbl) is a substantial subtree
// (layout, tx, numFmt, spPr, txPr) — kept as captured XmlElement
// until a later slice types it.

///|
/// Series-level fitted-curve overlay (`<c:trendline>`,
/// CT_Trendline). Applies to bar / line / area / scatter /
/// bubble series; pie / doughnut / radar / surface series do
/// not support trendlines.
pub(all) struct Trendline {
  /// `<c:name>` text content — display name shown in legend / labels.
  name : String?
  /// `<c:spPr>` (CT_ShapeProperties) — stroke / fill styling for the
  /// trendline curve. Captured.
  sp_pr : @xml.XmlElement?
  /// `<c:trendlineType val="…"/>` — REQUIRED.
  trendline_type : TrendlineType
  /// `<c:order val="…"/>` — polynomial order (only meaningful for
  /// `poly`). Schema default is 2; stored optional so we don't
  /// synthesise the default.
  order : Int?
  /// `<c:period val="…"/>` — moving-average period (only meaningful
  /// for `movingAvg`). Schema default is 2.
  period : Int?
  /// `<c:forward val="…"/>` — forecast forward (periods). Stored as
  /// String? to preserve the source token.
  forward : String?
  /// `<c:backward val="…"/>` — forecast backward (periods).
  backward : String?
  /// `<c:intercept val="…"/>` — explicit Y-intercept.
  intercept : String?
  /// `<c:dispRSqr val="…"/>` — show R² on the chart.
  disp_r_sqr : Bool?
  /// `<c:dispEq val="…"/>` — show the fitted equation.
  disp_eq : Bool?
  /// `<c:trendlineLbl>` (CT_TrendlineLbl). Captured until later
  /// typing.
  trendline_lbl : @xml.XmlElement?
  /// `<c:extLst>` and foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Trendline with fn output(self, logger) {
  logger.write_string("Trendline(")
  logger.write_string(self.trendline_type.to_xml())
  logger.write_string(")")
}

///|
/// `<c:trendlineType val="…"/>` (ST_TrendlineType).
pub(all) enum TrendlineType {
  /// `val="exp"` — exponential fit.
  TrendlineExp
  /// `val="linear"` — straight-line least-squares.
  TrendlineLinear
  /// `val="log"` — logarithmic fit.
  TrendlineLog
  /// `val="movingAvg"` — moving average (uses `period`).
  TrendlineMovingAvg
  /// `val="poly"` — polynomial fit (uses `order`).
  TrendlinePoly
  /// `val="power"` — power-law fit.
  TrendlinePower
} derive(Eq, Debug)

///|
pub impl Show for TrendlineType with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `TrendlineType` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn TrendlineType::from_xml(s : String) -> TrendlineType? {
  match s {
    "exp" => Some(TrendlineExp)
    "linear" => Some(TrendlineLinear)
    "log" => Some(TrendlineLog)
    "movingAvg" => Some(TrendlineMovingAvg)
    "poly" => Some(TrendlinePoly)
    "power" => Some(TrendlinePower)
    _ => None
  }
}

///|
/// Serialise `TrendlineType` back to the OOXML attribute string.
pub fn TrendlineType::to_xml(self : TrendlineType) -> String {
  match self {
    TrendlineExp => "exp"
    TrendlineLinear => "linear"
    TrendlineLog => "log"
    TrendlineMovingAvg => "movingAvg"
    TrendlinePoly => "poly"
    TrendlinePower => "power"
  }
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:trendline>` element into a typed `Trendline`.
/// Raises `Malformed` when the required `<c:trendlineType>` leaf is
/// absent or carries an unknown `val=`.
pub fn parse_trendline(el : @xml.XmlElement) -> Trendline raise ChartError {
  let mut name : String? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut trendline_type : TrendlineType? = None
  let mut order : Int? = None
  let mut period : Int? = None
  let mut forward : String? = None
  let mut backward : String? = None
  let mut intercept : String? = None
  let mut disp_r_sqr : Bool? = None
  let mut disp_eq : Bool? = None
  let mut trendline_lbl : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "name" => name = Some(extract_text_content(c))
            "spPr" => sp_pr = Some(c)
            "trendlineType" =>
              trendline_type = val_string(c).bind(TrendlineType::from_xml)
            "order" => order = val_int(c)
            "period" => period = val_int(c)
            "forward" => forward = val_string(c)
            "backward" => backward = val_string(c)
            "intercept" => intercept = val_string(c)
            "dispRSqr" => disp_r_sqr = val_bool(c)
            "dispEq" => disp_eq = val_bool(c)
            "trendlineLbl" => trendline_lbl = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let tt = match trendline_type {
    Some(t) => t
    None =>
      raise Malformed("<c:trendline> is missing required <c:trendlineType>")
  }
  {
    name,
    sp_pr,
    trendline_type: tt,
    order,
    period,
    forward,
    backward,
    intercept,
    disp_r_sqr,
    disp_eq,
    trendline_lbl,
    extension,
  }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:trendline>` element. Child order follows ECMA-376
/// §21.2.2.211: name → spPr → trendlineType → order → period →
/// forward → backward → intercept → dispRSqr → dispEq →
/// trendlineLbl → extension.
pub fn write_trendline(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  t : Trendline,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "trendline"))
  match t.name {
    Some(s) => {
      w.start_element(@xml.QName::new(@oxml.chart_ns, "name"))
      w.text(s)
      w.end_element()
    }
    None => ()
  }
  match t.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  emit_val_string(w, "trendlineType", t.trendline_type.to_xml())
  match t.order {
    Some(n) => emit_val_int(w, "order", n)
    None => ()
  }
  match t.period {
    Some(n) => emit_val_int(w, "period", n)
    None => ()
  }
  match t.forward {
    Some(v) => emit_val_string(w, "forward", v)
    None => ()
  }
  match t.backward {
    Some(v) => emit_val_string(w, "backward", v)
    None => ()
  }
  match t.intercept {
    Some(v) => emit_val_string(w, "intercept", v)
    None => ()
  }
  match t.disp_r_sqr {
    Some(b) => emit_val_bool(w, "dispRSqr", b)
    None => ()
  }
  match t.disp_eq {
    Some(b) => emit_val_bool(w, "dispEq", b)
    None => ()
  }
  match t.trendline_lbl {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in t.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
