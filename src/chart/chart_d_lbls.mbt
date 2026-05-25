// Typed data-labels body (CT_DLbls).
//
// `<c:dLbls>` (ECMA-376 §21.2.2.49, CT_DLbls) is the plot-level
// data-labels container. It appears as a child of every chart-family
// body that supports labelled data points (bar / line / pie / area /
// area3D / bar3D / line3D / pie3D / doughnut / radar / ofPie /
// scatter / bubble / stock — i.e. every standard family except
// surface / surface3D).
//
// Schema body:
//
//   <c:dLbl>*           (CT_DLbl — per-data-point overrides)
//   <c:numFmt>?         (CT_NumFmt)
//   <c:spPr>?           (CT_ShapeProperties)
//   <c:txPr>?           (CT_TextBody)
//   <c:dLblPos>?        (CT_DLblPos val=bestFit|b|ctr|inBase|inEnd|l|outEnd|r|t)
//   <c:showLegendKey>?  (CT_Boolean)
//   <c:showVal>?        (CT_Boolean)
//   <c:showCatName>?    (CT_Boolean)
//   <c:showSerName>?    (CT_Boolean)
//   <c:showPercent>?    (CT_Boolean)
//   <c:showBubbleSize>? (CT_Boolean)
//   <c:separator>?      (xsd:string)
//   <c:extLst>?
//
// Pie-family variants (`pieChart` / `doughnutChart` / `ofPieChart`)
// additionally allow `<c:showLeaderLines>` and `<c:leaderLines>`
// (CT_PieChartDLbls extension). These ride on `DLbls.extension` per
// ADR-004 — they're family-specific and we don't surface them on the
// base type today.
//
// Per-data-point overrides (`<c:dLbl>` ▸ CT_DLbl) keep round-tripping
// as captured `XmlElement` in `DLbls.d_lbl` until a later slice types
// CT_DLbl. The remaining EG_DLbls fields all lift to typed Bool /
// String / enum values.

///|
/// Data-labels styling (`<c:dLbls>`, CT_DLbls) attached to a
/// chart family. Carries the default styling plus an array of
/// per-data-point overrides.
pub(all) struct DLbls {
  /// `<c:dLbl>` per-data-point overrides. Each entry targets a
  /// single point by `idx`.
  d_lbl : Array[DLbl]
  /// `<c:numFmt>` (CT_NumFmt) — number-format string + sourceLinked.
  /// Reuses the axis-side `NumFmt` since the schema is identical.
  num_fmt : NumFmt?
  /// `<c:spPr>` (CT_ShapeProperties). Captured.
  sp_pr : @xml.XmlElement?
  /// `<c:txPr>` (CT_TextBody). Captured.
  tx_pr : @xml.XmlElement?
  /// `<c:dLblPos val="…"/>` — label placement relative to the data
  /// point.
  d_lbl_pos : DLblPos?
  /// `<c:showLegendKey val="…"/>` — show colour swatch next to label.
  show_legend_key : Bool?
  /// `<c:showVal val="…"/>` — show the numeric value.
  show_val : Bool?
  /// `<c:showCatName val="…"/>` — show the category name.
  show_cat_name : Bool?
  /// `<c:showSerName val="…"/>` — show the series name.
  show_ser_name : Bool?
  /// `<c:showPercent val="…"/>` — show the percentage (pie only).
  show_percent : Bool?
  /// `<c:showBubbleSize val="…"/>` — show the bubble size value
  /// (bubble only).
  show_bubble_size : Bool?
  /// `<c:separator>` (text content) — string used to separate
  /// concatenated label parts (e.g. "Value: 42 (50%)").
  separator : String?
  /// `<c:extLst>` plus pie-family-only `<c:showLeaderLines>` /
  /// `<c:leaderLines>` and any foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for DLbls with fn output(self, logger) {
  logger.write_string("DLbls(")
  logger.write_string(self.d_lbl.length().to_string())
  logger.write_string(" overrides)")
}

///|
/// `<c:dLblPos val="…"/>` (ST_DLblPos).
pub(all) enum DLblPos {
  /// `val="bestFit"` — let the renderer decide.
  DLblBestFit
  /// `val="b"` — below the data point.
  DLblBottom
  /// `val="ctr"` — centred on the data point.
  DLblCenter
  /// `val="inBase"` — inside the base of the bar.
  DLblInBase
  /// `val="inEnd"` — inside the end of the bar / wedge.
  DLblInEnd
  /// `val="l"` — to the left.
  DLblLeft
  /// `val="outEnd"` — outside the end of the bar / wedge.
  DLblOutEnd
  /// `val="r"` — to the right.
  DLblRight
  /// `val="t"` — above the data point.
  DLblTop
} derive(Eq, Debug)

///|
pub impl Show for DLblPos with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `DLblPos` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn DLblPos::from_xml(s : String) -> DLblPos? {
  match s {
    "bestFit" => Some(DLblBestFit)
    "b" => Some(DLblBottom)
    "ctr" => Some(DLblCenter)
    "inBase" => Some(DLblInBase)
    "inEnd" => Some(DLblInEnd)
    "l" => Some(DLblLeft)
    "outEnd" => Some(DLblOutEnd)
    "r" => Some(DLblRight)
    "t" => Some(DLblTop)
    _ => None
  }
}

///|
/// Serialise `DLblPos` back to the OOXML attribute string.
pub fn DLblPos::to_xml(self : DLblPos) -> String {
  match self {
    DLblBestFit => "bestFit"
    DLblBottom => "b"
    DLblCenter => "ctr"
    DLblInBase => "inBase"
    DLblInEnd => "inEnd"
    DLblLeft => "l"
    DLblOutEnd => "outEnd"
    DLblRight => "r"
    DLblTop => "t"
  }
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:dLbls>` element into a typed `DLbls`. May
/// raise `Malformed` via the per-point `parse_d_lbl` helper when a
/// `<c:dLbl>` child is missing its required `<c:idx>`.
pub fn parse_d_lbls(el : @xml.XmlElement) -> DLbls raise ChartError {
  let d_lbl : Array[DLbl] = []
  let mut num_fmt : NumFmt? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut tx_pr : @xml.XmlElement? = None
  let mut d_lbl_pos : DLblPos? = None
  let mut show_legend_key : Bool? = None
  let mut show_val : Bool? = None
  let mut show_cat_name : Bool? = None
  let mut show_ser_name : Bool? = None
  let mut show_percent : Bool? = None
  let mut show_bubble_size : Bool? = None
  let mut separator : String? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "dLbl" => d_lbl.push(parse_d_lbl(c))
            "numFmt" => num_fmt = Some(parse_num_fmt(c))
            "spPr" => sp_pr = Some(c)
            "txPr" => tx_pr = Some(c)
            "dLblPos" => d_lbl_pos = val_string(c).bind(DLblPos::from_xml)
            "showLegendKey" => show_legend_key = val_bool(c)
            "showVal" => show_val = val_bool(c)
            "showCatName" => show_cat_name = val_bool(c)
            "showSerName" => show_ser_name = val_bool(c)
            "showPercent" => show_percent = val_bool(c)
            "showBubbleSize" => show_bubble_size = val_bool(c)
            "separator" => separator = Some(extract_text_content(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  {
    d_lbl,
    num_fmt,
    sp_pr,
    tx_pr,
    d_lbl_pos,
    show_legend_key,
    show_val,
    show_cat_name,
    show_ser_name,
    show_percent,
    show_bubble_size,
    separator,
    extension,
  }
}

///|
/// Concatenate text-content children of an element. `<c:separator>`
/// holds plain text directly, not a `val="…"` attribute.
fn extract_text_content(el : @xml.XmlElement) -> String {
  let mut out = ""
  for n in el.children {
    match n {
      Text(s) => out = out + s
      CData(s) => out = out + s
      _ => ()
    }
  }
  out
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:dLbls>` element. Child order follows ECMA-376
/// §21.2.2.49 schema order: dLbl* → numFmt → spPr → txPr → dLblPos
/// → showLegendKey → showVal → showCatName → showSerName →
/// showPercent → showBubbleSize → separator → extension.
pub fn write_d_lbls(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  dl : DLbls,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "dLbls"))
  for d in dl.d_lbl {
    write_d_lbl(w, ctx, d)
  }
  match dl.num_fmt {
    Some(nf) => write_num_fmt(w, nf)
    None => ()
  }
  match dl.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match dl.tx_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match dl.d_lbl_pos {
    Some(p) => emit_val_string(w, "dLblPos", p.to_xml())
    None => ()
  }
  match dl.show_legend_key {
    Some(b) => emit_val_bool(w, "showLegendKey", b)
    None => ()
  }
  match dl.show_val {
    Some(b) => emit_val_bool(w, "showVal", b)
    None => ()
  }
  match dl.show_cat_name {
    Some(b) => emit_val_bool(w, "showCatName", b)
    None => ()
  }
  match dl.show_ser_name {
    Some(b) => emit_val_bool(w, "showSerName", b)
    None => ()
  }
  match dl.show_percent {
    Some(b) => emit_val_bool(w, "showPercent", b)
    None => ()
  }
  match dl.show_bubble_size {
    Some(b) => emit_val_bool(w, "showBubbleSize", b)
    None => ()
  }
  match dl.separator {
    Some(s) => {
      w.start_element(@xml.QName::new(@oxml.chart_ns, "separator"))
      w.text(s)
      w.end_element()
    }
    None => ()
  }
  for ext in dl.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
