// Typed chart-series cores.
//
// Each `<c:*Chart>` family carries one or more `<c:ser>` children
// (CT_BarSer / CT_LineSer / CT_PieSer / CT_ScatterSer / CT_BubbleSer
// / …). Across the families, every series shares:
//
//   - `<c:idx val="…"/>`   — series index (REQUIRED, UInt)
//   - `<c:order val="…"/>` — render order (REQUIRED, UInt)
//   - `<c:tx>`             — series title (optional)
//   - `<c:spPr>`           — series shape / styling (optional)
//   - `<c:extLst>`         — extension list (optional)
//
// The data-source children differ: bar / line / pie / area / radar /
// doughnut / stock / surface / ofPie + their 3D variants use
// `<c:cat>` (categories) + `<c:val>` (values). Scatter uses
// `<c:xVal>` + `<c:yVal>`. Bubble adds `<c:bubbleSize>` (+ optional
// `<c:bubble3D>`).
//
// We therefore type three core flavours:
//
//   - `ChartSeriesCore`   — idx / order / tx / sp_pr / cat / val
//   - `ScatterSeriesCore` — idx / order / tx / sp_pr / x_val / y_val
//   - `BubbleSeriesCore`  — idx / order / tx / sp_pr / x_val / y_val
//                           / bubble_size
//
// The data-source bodies themselves (`<c:strRef>` + `<c:strCache>`,
// `<c:numRef>` + `<c:numCache>`, `<c:strLit>`, `<c:numLit>`) keep
// round-tripping as captured `XmlElement?` — typed `AxDataSource` /
// `NumDataSource` ASTs are a later expansion point. Family-specific
// children that we don't lift (`<c:dPt>`, `<c:dLbls>`, `<c:trendline>`,
// `<c:errBars>`, `<c:marker>`, `<c:smooth>`, `<c:explosion>`,
// `<c:invertIfNegative>`, `<c:pictureOptions>`, `<c:bubble3D>`,
// `<c:shape>`) ride on `extension` per ADR-004.

///|
/// The body of a `<c:ser>` element for chart families that use
/// category + value data sources (bar / line / pie / doughnut /
/// area / radar / stock / surface / ofPie, plus the 3D variants).
pub(all) struct ChartSeriesCore {
  /// `<c:idx val="…"/>` — series index. Used as the key in
  /// combination charts and for `<c:dPt>` overrides. REQUIRED.
  idx : Int
  /// `<c:order val="…"/>` — render order. REQUIRED.
  order : Int
  /// `<c:tx>` — series title. Captured XmlElement until the typed
  /// `SeriesText` AST lands.
  tx : @xml.XmlElement?
  /// `<c:spPr>` — series-level shape properties (fill / stroke /
  /// effect). Captured XmlElement until the existing
  /// `<p:spPr>`-style parser is rewired here.
  sp_pr : @xml.XmlElement?
  /// `<c:cat>` — category axis data source. Captured XmlElement;
  /// typed `AxDataSource` is a future slice.
  cat : @xml.XmlElement?
  /// `<c:val>` — value data source. Captured XmlElement; typed
  /// `NumDataSource` is a future slice.
  val : @xml.XmlElement?
  /// Family-specific unmodelled children (`<c:dLbls>`, `<c:dPt>`,
  /// `<c:trendline>`, `<c:errBars>`, `<c:marker>`, `<c:smooth>`,
  /// `<c:explosion>`, `<c:invertIfNegative>`, `<c:pictureOptions>`,
  /// `<c:shape>`, `<c:extLst>`, foreign-namespace siblings) plus
  /// the `<c:tx>` / `<c:cat>` / `<c:val>` children when they appear
  /// in a position the lifter doesn't expect.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartSeriesCore with fn output(self, logger) {
  logger.write_string("ChartSeriesCore(idx=")
  logger.write_string(self.idx.to_string())
  logger.write_string(")")
}

///|
/// The body of a `<c:ser>` element for the scatter chart family.
/// Scatter has two value axes — both data sources are numeric.
pub(all) struct ScatterSeriesCore {
  idx : Int
  order : Int
  tx : @xml.XmlElement?
  sp_pr : @xml.XmlElement?
  /// `<c:xVal>` — X-axis numeric data source.
  x_val : @xml.XmlElement?
  /// `<c:yVal>` — Y-axis numeric data source.
  y_val : @xml.XmlElement?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ScatterSeriesCore with fn output(self, logger) {
  logger.write_string("ScatterSeriesCore(idx=")
  logger.write_string(self.idx.to_string())
  logger.write_string(")")
}

///|
/// The body of a `<c:ser>` element for the bubble chart family.
/// Adds a third numeric data source `<c:bubbleSize>` on top of
/// scatter's X / Y.
pub(all) struct BubbleSeriesCore {
  idx : Int
  order : Int
  tx : @xml.XmlElement?
  sp_pr : @xml.XmlElement?
  x_val : @xml.XmlElement?
  y_val : @xml.XmlElement?
  /// `<c:bubbleSize>` — third numeric data source mapping bubble
  /// area / width.
  bubble_size : @xml.XmlElement?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for BubbleSeriesCore with fn output(self, logger) {
  logger.write_string("BubbleSeriesCore(idx=")
  logger.write_string(self.idx.to_string())
  logger.write_string(")")
}

// --- parsing -----------------------------------------------------------------

///|
/// Parse a captured `<c:ser>` element into a typed `ChartSeriesCore`.
/// Used by every chart family that has cat + val data sources.
///
/// Raises `Malformed` if the required `<c:idx>` or `<c:order>` leaves
/// are missing — both are spec-required.
pub fn parse_chart_series_core(
  el : @xml.XmlElement,
) -> ChartSeriesCore raise ChartError {
  let mut idx : Int? = None
  let mut order : Int? = None
  let mut tx : @xml.XmlElement? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut cat : @xml.XmlElement? = None
  let mut val : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "idx" => idx = val_int(c)
            "order" => order = val_int(c)
            "tx" => tx = Some(c)
            "spPr" => sp_pr = Some(c)
            "cat" => cat = Some(c)
            "val" => val = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let i = match idx {
    Some(n) => n
    None => raise Malformed("<c:ser> is missing required <c:idx>")
  }
  // `<c:order>` is schema-required, but a handful of real-world files
  // and minimal test fixtures omit it. Be lenient: fall back to `idx`,
  // matching PowerPoint / LibreOffice behaviour. On write we always
  // emit both leaves.
  let o = order.unwrap_or(i)
  { idx: i, order: o, tx, sp_pr, cat, val, extension }
}

///|
/// Parse a captured `<c:ser>` element into a typed `ScatterSeriesCore`.
pub fn parse_scatter_series_core(
  el : @xml.XmlElement,
) -> ScatterSeriesCore raise ChartError {
  let mut idx : Int? = None
  let mut order : Int? = None
  let mut tx : @xml.XmlElement? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut x_val : @xml.XmlElement? = None
  let mut y_val : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "idx" => idx = val_int(c)
            "order" => order = val_int(c)
            "tx" => tx = Some(c)
            "spPr" => sp_pr = Some(c)
            "xVal" => x_val = Some(c)
            "yVal" => y_val = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let i = match idx {
    Some(n) => n
    None => raise Malformed("<c:ser> is missing required <c:idx>")
  }
  // `<c:order>` is schema-required, but a handful of real-world files
  // and minimal test fixtures omit it. Be lenient: fall back to `idx`,
  // matching PowerPoint / LibreOffice behaviour. On write we always
  // emit both leaves.
  let o = order.unwrap_or(i)
  { idx: i, order: o, tx, sp_pr, x_val, y_val, extension }
}

///|
/// Parse a captured `<c:ser>` element into a typed `BubbleSeriesCore`.
pub fn parse_bubble_series_core(
  el : @xml.XmlElement,
) -> BubbleSeriesCore raise ChartError {
  let mut idx : Int? = None
  let mut order : Int? = None
  let mut tx : @xml.XmlElement? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut x_val : @xml.XmlElement? = None
  let mut y_val : @xml.XmlElement? = None
  let mut bubble_size : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "idx" => idx = val_int(c)
            "order" => order = val_int(c)
            "tx" => tx = Some(c)
            "spPr" => sp_pr = Some(c)
            "xVal" => x_val = Some(c)
            "yVal" => y_val = Some(c)
            "bubbleSize" => bubble_size = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let i = match idx {
    Some(n) => n
    None => raise Malformed("<c:ser> is missing required <c:idx>")
  }
  // `<c:order>` is schema-required, but a handful of real-world files
  // and minimal test fixtures omit it. Be lenient: fall back to `idx`,
  // matching PowerPoint / LibreOffice behaviour. On write we always
  // emit both leaves.
  let o = order.unwrap_or(i)
  { idx: i, order: o, tx, sp_pr, x_val, y_val, bubble_size, extension }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:ser>` element from a `ChartSeriesCore`. Child order
/// follows the ECMA-376 schema: idx → order → tx → spPr → cat →
/// val → extension tail.
pub fn write_chart_series_core(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  s : ChartSeriesCore,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "ser"))
  emit_idx_order(w, s.idx, s.order)
  match s.tx {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.cat {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.val {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in s.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit a `<c:ser>` element from a `ScatterSeriesCore`.
pub fn write_scatter_series_core(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  s : ScatterSeriesCore,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "ser"))
  emit_idx_order(w, s.idx, s.order)
  match s.tx {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.x_val {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.y_val {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in s.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit a `<c:ser>` element from a `BubbleSeriesCore`.
pub fn write_bubble_series_core(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  s : BubbleSeriesCore,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "ser"))
  emit_idx_order(w, s.idx, s.order)
  match s.tx {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.x_val {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.y_val {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match s.bubble_size {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in s.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Shared idx + order leaf emitter.
fn emit_idx_order(
  w : @xml.XmlWriter,
  idx : Int,
  order : Int,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "idx"))
  w.attribute(@xml.QName::unqualified("val"), idx.to_string())
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.chart_ns, "order"))
  w.attribute(@xml.QName::unqualified("val"), order.to_string())
  w.end_element()
}
