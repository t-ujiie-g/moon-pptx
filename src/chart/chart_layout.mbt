// Typed layout / manual-layout body (CT_Layout + CT_ManualLayout).
//
// `<c:layout>` is the positioning hint used by `<c:title>` /
// `<c:legend>` / `<c:dLbl>` / `<c:plotArea>` to override the
// auto-layout the renderer would otherwise compute.
//
// Schema (ECMA-376 §21.2.2.96, CT_Layout):
//
//   <c:manualLayout>?  (CT_ManualLayout)
//   <c:extLst>?
//
// CT_ManualLayout (§21.2.2.101):
//
//   <c:layoutTarget>?  (CT_LayoutTarget val=inner|outer)
//   <c:xMode>?         (CT_LayoutMode val=edge|factor)
//   <c:yMode>?
//   <c:wMode>?
//   <c:hMode>?
//   <c:x>?             (CT_Double — fractional position)
//   <c:y>?
//   <c:w>?
//   <c:h>?
//   <c:extLst>?
//
// Floating-point coordinates (`<c:x>` / `<c:y>` / `<c:w>` / `<c:h>`)
// carry as `String?` to preserve the source representation losslessly,
// mirroring how `Scaling.{max,min,log_base}` and `crossesAt` are
// handled elsewhere in this package.

///|
/// Body of a `<c:layout>` element. Optionally wraps a
/// `<c:manualLayout>` with explicit positioning.
pub(all) struct Layout {
  /// `<c:manualLayout>` — explicit positioning override.
  manual_layout : ManualLayout?
  /// `<c:extLst>` and foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Layout with fn output(self, logger) {
  logger.write_string("Layout { … }")
  let _ = self
}

///|
/// Manual-layout coordinates (CT_ManualLayout).
pub(all) struct ManualLayout {
  /// `<c:layoutTarget val="…"/>` — whether the rect targets the
  /// inner (plot) or outer (chart area) box. Default `outer`.
  layout_target : LayoutTarget?
  /// `<c:xMode val="…"/>` — coordinate interpretation for x.
  /// Default `factor` (relative to the chart area).
  x_mode : LayoutMode?
  /// `<c:yMode val="…"/>` — coordinate interpretation for y.
  y_mode : LayoutMode?
  /// `<c:wMode val="…"/>` — width interpretation.
  w_mode : LayoutMode?
  /// `<c:hMode val="…"/>` — height interpretation.
  h_mode : LayoutMode?
  /// `<c:x val="…"/>` — left position. Stored as `String?` to
  /// preserve the source token (avoids float-format drift).
  x : String?
  /// `<c:y val="…"/>` — top position.
  y : String?
  /// `<c:w val="…"/>` — width.
  w : String?
  /// `<c:h val="…"/>` — height.
  h : String?
  /// `<c:extLst>` and foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ManualLayout with fn output(self, logger) {
  logger.write_string("ManualLayout { … }")
  let _ = self
}

///|
/// `<c:layoutTarget val="…"/>` (ST_LayoutTarget).
pub(all) enum LayoutTarget {
  /// `val="inner"` — coordinates are relative to the plot area.
  LayoutInner
  /// `val="outer"` — coordinates are relative to the chart area
  /// (default).
  LayoutOuter
} derive(Eq, Debug)

///|
pub impl Show for LayoutTarget with fn output(self, logger) {
  match self {
    LayoutInner => logger.write_string("LayoutInner")
    LayoutOuter => logger.write_string("LayoutOuter")
  }
}

///|
/// Parse `LayoutTarget` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn LayoutTarget::from_xml(s : String) -> LayoutTarget? {
  match s {
    "inner" => Some(LayoutInner)
    "outer" => Some(LayoutOuter)
    _ => None
  }
}

///|
/// Serialise `LayoutTarget` back to the OOXML attribute string.
pub fn LayoutTarget::to_xml(self : LayoutTarget) -> String {
  match self {
    LayoutInner => "inner"
    LayoutOuter => "outer"
  }
}

///|
/// `<c:xMode val="…"/>` / `<c:yMode val="…"/>` / `<c:wMode val="…"/>` /
/// `<c:hMode val="…"/>` (ST_LayoutMode).
pub(all) enum LayoutMode {
  /// `val="edge"` — the coordinate names an absolute edge position.
  LayoutEdge
  /// `val="factor"` — the coordinate is a fraction of the chart-area
  /// dimension (default).
  LayoutFactor
} derive(Eq, Debug)

///|
pub impl Show for LayoutMode with fn output(self, logger) {
  match self {
    LayoutEdge => logger.write_string("LayoutEdge")
    LayoutFactor => logger.write_string("LayoutFactor")
  }
}

///|
/// Parse `LayoutMode` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn LayoutMode::from_xml(s : String) -> LayoutMode? {
  match s {
    "edge" => Some(LayoutEdge)
    "factor" => Some(LayoutFactor)
    _ => None
  }
}

///|
/// Serialise `LayoutMode` back to the OOXML attribute string.
pub fn LayoutMode::to_xml(self : LayoutMode) -> String {
  match self {
    LayoutEdge => "edge"
    LayoutFactor => "factor"
  }
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:layout>` element into a typed `Layout`.
pub fn parse_layout(el : @xml.XmlElement) -> Layout {
  let mut manual_layout : ManualLayout? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "manualLayout" => manual_layout = Some(parse_manual_layout(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { manual_layout, extension }
}

///|
fn parse_manual_layout(el : @xml.XmlElement) -> ManualLayout {
  let mut layout_target : LayoutTarget? = None
  let mut x_mode : LayoutMode? = None
  let mut y_mode : LayoutMode? = None
  let mut w_mode : LayoutMode? = None
  let mut h_mode : LayoutMode? = None
  let mut x : String? = None
  let mut y : String? = None
  let mut w : String? = None
  let mut h : String? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "layoutTarget" =>
              layout_target = val_string(c).bind(LayoutTarget::from_xml)
            "xMode" => x_mode = val_string(c).bind(LayoutMode::from_xml)
            "yMode" => y_mode = val_string(c).bind(LayoutMode::from_xml)
            "wMode" => w_mode = val_string(c).bind(LayoutMode::from_xml)
            "hMode" => h_mode = val_string(c).bind(LayoutMode::from_xml)
            "x" => x = val_string(c)
            "y" => y = val_string(c)
            "w" => w = val_string(c)
            "h" => h = val_string(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { layout_target, x_mode, y_mode, w_mode, h_mode, x, y, w, h, extension }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:layout>` element. Child order follows ECMA-376
/// §21.2.2.96: manualLayout → extension.
pub fn write_layout(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  l : Layout,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "layout"))
  match l.manual_layout {
    Some(ml) => write_manual_layout(w, ctx, ml)
    None => ()
  }
  for ext in l.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit a `<c:manualLayout>` element. Child order follows ECMA-376
/// §21.2.2.101: layoutTarget → xMode → yMode → wMode → hMode →
/// x → y → w → h → extension.
fn write_manual_layout(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  ml : ManualLayout,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "manualLayout"))
  match ml.layout_target {
    Some(t) => emit_val_string(w, "layoutTarget", t.to_xml())
    None => ()
  }
  match ml.x_mode {
    Some(m) => emit_val_string(w, "xMode", m.to_xml())
    None => ()
  }
  match ml.y_mode {
    Some(m) => emit_val_string(w, "yMode", m.to_xml())
    None => ()
  }
  match ml.w_mode {
    Some(m) => emit_val_string(w, "wMode", m.to_xml())
    None => ()
  }
  match ml.h_mode {
    Some(m) => emit_val_string(w, "hMode", m.to_xml())
    None => ()
  }
  match ml.x {
    Some(v) => emit_val_string(w, "x", v)
    None => ()
  }
  match ml.y {
    Some(v) => emit_val_string(w, "y", v)
    None => ()
  }
  match ml.w {
    Some(v) => emit_val_string(w, "w", v)
    None => ()
  }
  match ml.h {
    Some(v) => emit_val_string(w, "h", v)
    None => ()
  }
  for ext in ml.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
