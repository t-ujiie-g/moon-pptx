// Typed chart-legend body (CT_Legend).
//
// `<c:legend>` is a chart-level child of `<c:chart>` (ECMA-376
// §21.2.2.93, CT_Legend):
//
//   <c:legendPos>?    (CT_LegendPos val=r/t/l/b/tr)
//   <c:legendEntry>*  (CT_LegendEntry — per-entry overrides)
//   <c:layout>?       (CT_Layout)
//   <c:overlay>?      (CT_Boolean)
//   <c:spPr>?         (CT_ShapeProperties)
//   <c:txPr>?         (CT_TextBody)
//   <c:extLst>?
//
// Scalar / enum / collection leaves are typed:
//   - legendPos → `LegendPos` enum
//   - overlay → Bool
//   - legendEntry* → `Array[LegendEntry]` (one per entry)
//
// Substantial subtrees (layout, spPr, txPr) keep round-tripping as
// captured XmlElement until later slices type them. Foreign-namespace
// + `<c:extLst>` ride on `ChartLegend.extension` per ADR-004.
//
// `<c:legendEntry>` (CT_LegendEntry, §21.2.2.94) carries a required
// `<c:idx>` plus an EG_LegendEntryData group whose only members in
// the spec are `<c:delete>` or `<c:txPr>` — captured wholesale on
// `LegendEntry.tx_pr` (only one or the other is meaningful in
// practice).

///|
/// Body of `<c:legend>` (CT_Legend) — chart legend positioning
/// and per-entry overrides.
///
/// - `legend_pos` (`<c:legendPos val="…"/>`) — where the legend sits.
/// - `legend_entries` (`<c:legendEntry>`) — per-entry visibility / formatting
///   overrides.
/// - `layout` — `<c:layout>` (CT_Layout). Captured.
/// - `overlay` (`<c:overlay val="…"/>`) — when `true`, the legend overlays
///   the plot area instead of reserving space outside it.
/// - `sp_pr` — `<c:spPr>` (CT_ShapeProperties) — legend-box fill / stroke /
///   effect. Captured.
/// - `tx_pr` — `<c:txPr>` (CT_TextBody) — default text styling for legend
///   entries. Captured.
pub(all) struct ChartLegend {
  legend_pos : LegendPos?
  legend_entries : Array[LegendEntry]
  layout : Layout?
  overlay : Bool?
  sp_pr : @xml.XmlElement?
  tx_pr : @xml.XmlElement?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartLegend with fn output(self, logger) {
  logger.write_string("ChartLegend(")
  logger.write_string(self.legend_entries.length().to_string())
  logger.write_string(" entries)")
}

///|
/// `<c:legendPos val="…"/>` (ST_LegendPos).
///
/// - `LegendBottom` (`val="b"`) — bottom.
/// - `LegendTopRight` (`val="tr"`) — top-right (corner placement).
/// - `LegendLeft` (`val="l"`) — left.
/// - `LegendRight` (`val="r"`) — right (default in PowerPoint).
/// - `LegendTop` (`val="t"`) — top.
pub(all) enum LegendPos {
  LegendBottom
  LegendTopRight
  LegendLeft
  LegendRight
  LegendTop
} derive(Eq, Debug)

///|
pub impl Show for LegendPos with fn output(self, logger) {
  match self {
    LegendBottom => logger.write_string("LegendBottom")
    LegendTopRight => logger.write_string("LegendTopRight")
    LegendLeft => logger.write_string("LegendLeft")
    LegendRight => logger.write_string("LegendRight")
    LegendTop => logger.write_string("LegendTop")
  }
}

///|
/// Parse `LegendPos` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn LegendPos::from_xml(s : String) -> LegendPos? {
  match s {
    "b" => Some(LegendBottom)
    "tr" => Some(LegendTopRight)
    "l" => Some(LegendLeft)
    "r" => Some(LegendRight)
    "t" => Some(LegendTop)
    _ => None
  }
}

///|
/// Serialise `LegendPos` back to the OOXML attribute string.
pub fn LegendPos::to_xml(self : LegendPos) -> String {
  match self {
    LegendBottom => "b"
    LegendTopRight => "tr"
    LegendLeft => "l"
    LegendRight => "r"
    LegendTop => "t"
  }
}

///|
/// Per-legend-entry overrides (CT_LegendEntry, §21.2.2.94). Each
/// entry targets a series / data-point by `<c:idx>`. The body
/// element is a choice (EG_LegendEntryData):
///
///   - `<c:delete val="1"/>` — hide this entry from the legend.
///   - `<c:txPr>` — override text formatting for this entry.
///
/// Both are stored optional so the source choice round-trips
/// faithfully (in practice only one is present at a time).
///
/// - `idx` (`<c:idx val="…"/>`) — REQUIRED. Identifies which legend slot this
///   entry targets.
/// - `delete` (`<c:delete val="…"/>`) — when present and `true`, hide the
///   entry.
/// - `tx_pr` — `<c:txPr>` (CT_TextBody) — per-entry text override. Captured.
pub(all) struct LegendEntry {
  idx : Int
  delete : Bool?
  tx_pr : @xml.XmlElement?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for LegendEntry with fn output(self, logger) {
  logger.write_string("LegendEntry(idx=")
  logger.write_string(self.idx.to_string())
  logger.write_string(")")
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:legend>` element into a typed `ChartLegend`.
fn parse_chart_legend(el : @xml.XmlElement) -> ChartLegend raise ChartError {
  let mut legend_pos : LegendPos? = None
  let legend_entries : Array[LegendEntry] = []
  let mut layout : Layout? = None
  let mut overlay : Bool? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut tx_pr : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "legendPos" => legend_pos = val_string(c).bind(LegendPos::from_xml)
            "legendEntry" => legend_entries.push(parse_legend_entry(c))
            "layout" => layout = Some(parse_layout(c))
            "overlay" => overlay = val_bool(c)
            "spPr" => sp_pr = Some(c)
            "txPr" => tx_pr = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { legend_pos, legend_entries, layout, overlay, sp_pr, tx_pr, extension, }
}

///|
fn parse_legend_entry(el : @xml.XmlElement) -> LegendEntry raise ChartError {
  let mut idx : Int? = None
  let mut delete : Bool? = None
  let mut tx_pr : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "idx" => idx = val_int(c)
            "delete" => delete = val_bool(c)
            "txPr" => tx_pr = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let id = match idx {
    Some(n) => n
    None => raise Malformed("<c:legendEntry> is missing required <c:idx>")
  }
  { idx: id, delete, tx_pr, extension, }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:legend>` element. Child order follows ECMA-376
/// §21.2.2.93: legendPos → legendEntry* → layout → overlay → spPr →
/// txPr → extension.
fn write_chart_legend(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  lg : ChartLegend,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "legend"))
  match lg.legend_pos {
    Some(p) => emit_val_string(w, "legendPos", p.to_xml())
    None => ()
  }
  for entry in lg.legend_entries {
    write_legend_entry(w, ctx, entry)
  }
  match lg.layout {
    Some(l) => write_layout(w, ctx, l)
    None => ()
  }
  match lg.overlay {
    Some(b) => emit_val_bool(w, "overlay", b)
    None => ()
  }
  match lg.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match lg.tx_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in lg.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_legend_entry(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  entry : LegendEntry,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "legendEntry"))
  emit_val_int(w, "idx", entry.idx)
  match entry.delete {
    Some(b) => emit_val_bool(w, "delete", b)
    None => ()
  }
  match entry.tx_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in entry.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
