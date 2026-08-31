// Typed axis bodies (CT_AxBase shared core).
//
// Every chart family that names an axis (`<c:catAx>` / `<c:valAx>` /
// `<c:dateAx>` / `<c:serAx>`) extends `CT_AxBase` — the shared block
// of fields specified by ECMA-376 §21.2.2.34:
//
//   <c:axId>            (REQUIRED, UInt)
//   <c:scaling>         (REQUIRED CT_Scaling)
//   <c:delete>          (optional Bool)
//   <c:axPos>           (REQUIRED, ST_AxPos)
//   <c:majorGridlines>? (CT_ChartLines)
//   <c:minorGridlines>? (CT_ChartLines)
//   <c:title>?          (CT_Title)
//   <c:numFmt>?         (CT_NumFmt)
//   <c:majorTickMark>?  (CT_TickMark, default "out")
//   <c:minorTickMark>?  (CT_TickMark, default "none")
//   <c:tickLblPos>?     (CT_TickLblPos)
//   <c:spPr>?           (CT_ShapeProperties)
//   <c:txPr>?           (CT_TextBody)
//   <c:crossAx>         (REQUIRED, UInt)
//   <c:crosses>?        (CT_Crosses)
//   <c:crossesAt>?      (CT_Double)
//
// Per-axis-kind extras (CT_CatAx's `lblOffset` / `tickLblSkip` /
// `auto`, CT_ValAx's `crossBetween` / `majorUnit` / `dispUnits`,
// CT_DateAx's `baseTimeUnit` / `majorTimeUnit`, CT_SerAx's
// `tickLblSkip` / `tickMarkSkip`, plus `<c:extLst>` and any
// foreign-namespace siblings) ride on `AxisCore.extension` per
// ADR-004 — they round-trip verbatim until later slices type them.
//
// Schema-required fields are stored as `Option` on the model: the
// parser is lenient (defaults to `None` if absent) so minimal-but-
// non-canonical fixtures still round-trip, and the writer emits a
// child only when the field is `Some`. A user-built axis (see
// `simple_axis_core` in `builders.mbt`) sets every required field
// to `Some` so the produced XML is schema-valid.

///|
/// Body of any of the four axis elements (`<c:catAx>` / `<c:valAx>` /
/// `<c:dateAx>` / `<c:serAx>`). The axis-kind discriminator lives on
/// the surrounding `Axis` enum variant, not in the body.
///
/// - `ax_id` (`<c:axId val="…"/>`) — REQUIRED. Identifies this axis so other
///   chart elements can cross-reference it.
/// - `scaling` — `<c:scaling>` (CT_Scaling). Schema-required; stored optional
///   so pathological / minimal fixtures still parse.
/// - `delete` (`<c:delete val="…"/>`) — when `true`, the axis is hidden but
///   the chart still references it for data layout.
/// - `ax_pos` (`<c:axPos val="…"/>`) — anchor side. Schema-required; stored
///   optional for the same reason as `scaling`.
/// - `major_gridlines` — `<c:majorGridlines>` (CT_ChartLines). Optional;
///   captured verbatim — typed when the gridline styling slice lands.
/// - `minor_gridlines` — `<c:minorGridlines>` (CT_ChartLines). Optional;
///   captured.
/// - `title` — `<c:title>` (CT_Title) — typed body.
/// - `num_fmt` — `<c:numFmt formatCode="…" sourceLinked="…"/>`. Optional.
/// - `major_tick_mark` — `<c:majorTickMark val="…"/>`. Defaults to `Out` if
///   absent on the surface (the spec default is "out"), but we don't
///   synthesise the default here — the field stays `None` so writers don't
///   emit a redundant child.
/// - `minor_tick_mark` — `<c:minorTickMark val="…"/>`.
/// - `tick_lbl_pos` (`<c:tickLblPos val="…"/>`) — tick-label placement.
/// - `sp_pr` — `<c:spPr>` (CT_ShapeProperties) — axis line / fill styling.
///   Captured.
/// - `tx_pr` — `<c:txPr>` (CT_TextBody) — axis-label run styling. Captured.
/// - `cross_ax` (`<c:crossAx val="…"/>`) — the paired axis this one crosses.
///   Schema-required; stored optional.
/// - `crosses` (`<c:crosses val="…"/>`) — choice with `crossesAt`.
/// - `crosses_at` (`<c:crossesAt val="…"/>`) — alternative to `crosses`.
///   Stored as `String?` to round-trip the source token verbatim (the value
///   is a `Double` but we want to dodge float-format drift, matching how
///   `OfPieChartBody.split_pos` is handled).
pub(all) struct AxisCore {
  ax_id : Int
  scaling : Scaling?
  delete : Bool?
  ax_pos : AxPos?
  major_gridlines : @xml.XmlElement?
  minor_gridlines : @xml.XmlElement?
  title : ChartTitle?
  num_fmt : NumFmt?
  major_tick_mark : TickMark?
  minor_tick_mark : TickMark?
  tick_lbl_pos : TickLblPos?
  sp_pr : @xml.XmlElement?
  tx_pr : @xml.XmlElement?
  cross_ax : Int?
  crosses : Crosses?
  crosses_at : String?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for AxisCore with fn output(self, logger) {
  logger.write_string("AxisCore(axId=")
  logger.write_string(self.ax_id.to_string())
  logger.write_string(")")
}

///|
/// `<c:scaling>` body (CT_Scaling, §21.2.2.43). All four children are
/// optional; an empty `<c:scaling/>` is valid.
///
/// - `log_base` (`<c:logBase val="…"/>`) — value-axis logarithmic base, in
///   [2.0, 1000.0]. Stored as `String?` to preserve the source representation
///   losslessly.
/// - `orientation` (`<c:orientation val="…"/>`) — value direction.
/// - `max` (`<c:max val="…"/>`) — explicit axis maximum. `String?` to
///   preserve representation.
/// - `min` (`<c:min val="…"/>`) — explicit axis minimum. `String?`.
pub(all) struct Scaling {
  log_base : String?
  orientation : Orientation?
  max : String?
  min : String?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Scaling with fn output(self, logger) {
  logger.write_string("Scaling { … }")
  let _ = self
}

///|
/// `<c:orientation val="…"/>` (ST_Orientation).
///
/// - `MinMax` (`val="minMax"`) — values increase from min toward max along
///   the axis (the usual configuration).
/// - `MaxMin` (`val="maxMin"`) — values decrease, flipping the axis.
pub(all) enum Orientation {
  MinMax
  MaxMin
} derive(Eq, Debug)

///|
pub impl Show for Orientation with fn output(self, logger) {
  match self {
    MinMax => logger.write_string("MinMax")
    MaxMin => logger.write_string("MaxMin")
  }
}

///|
/// Parse `Orientation` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn Orientation::from_xml(s : String) -> Orientation? {
  match s {
    "minMax" => Some(MinMax)
    "maxMin" => Some(MaxMin)
    _ => None
  }
}

///|
/// Serialise `Orientation` back to the OOXML attribute string.
pub fn Orientation::to_xml(self : Orientation) -> String {
  match self {
    MinMax => "minMax"
    MaxMin => "maxMin"
  }
}

///|
/// `<c:axPos val="…"/>` (ST_AxPos).
///
/// - `Bottom` (`val="b"`) — bottom (usual for catAx in a vertical bar chart).
/// - `Left` (`val="l"`) — left (usual for valAx in a vertical bar chart).
/// Direct attribute mappings: `Right`→`val="r"`, `Top`→`val="t"`.
pub(all) enum AxPos {
  Bottom
  Left
  Right
  Top
} derive(Eq, Debug)

///|
pub impl Show for AxPos with fn output(self, logger) {
  match self {
    Bottom => logger.write_string("Bottom")
    Left => logger.write_string("Left")
    Right => logger.write_string("Right")
    Top => logger.write_string("Top")
  }
}

///|
/// Parse `AxPos` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn AxPos::from_xml(s : String) -> AxPos? {
  match s {
    "b" => Some(Bottom)
    "l" => Some(Left)
    "r" => Some(Right)
    "t" => Some(Top)
    _ => None
  }
}

///|
/// Serialise `AxPos` back to the OOXML attribute string.
pub fn AxPos::to_xml(self : AxPos) -> String {
  match self {
    Bottom => "b"
    Left => "l"
    Right => "r"
    Top => "t"
  }
}

///|
/// `<c:majorTickMark val="…"/>` / `<c:minorTickMark val="…"/>`
/// (ST_TickMark).
///
/// - `Cross` (`val="cross"`) — tick crosses the axis.
/// - `In` (`val="in"`) — tick on the inside of the plot.
/// - `NoTick` (`val="none"`) — no tick.
/// - `Out` (`val="out"`) — tick on the outside (default).
pub(all) enum TickMark {
  Cross
  In
  NoTick
  Out
} derive(Eq, Debug)

///|
pub impl Show for TickMark with fn output(self, logger) {
  match self {
    Cross => logger.write_string("Cross")
    In => logger.write_string("In")
    NoTick => logger.write_string("NoTick")
    Out => logger.write_string("Out")
  }
}

///|
/// Parse `TickMark` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn TickMark::from_xml(s : String) -> TickMark? {
  match s {
    "cross" => Some(Cross)
    "in" => Some(In)
    "none" => Some(NoTick)
    "out" => Some(Out)
    _ => None
  }
}

///|
/// Serialise `TickMark` back to the OOXML attribute string.
pub fn TickMark::to_xml(self : TickMark) -> String {
  match self {
    Cross => "cross"
    In => "in"
    NoTick => "none"
    Out => "out"
  }
}

///|
/// `<c:tickLblPos val="…"/>` (ST_TickLblPos).
///
/// - `High` (`val="high"`) — labels on the high side of the axis.
/// - `Low` (`val="low"`) — labels on the low side.
/// - `NextTo` (`val="nextTo"`) — labels next to the axis (typical default).
/// - `NoLbl` (`val="none"`) — labels hidden.
pub(all) enum TickLblPos {
  High
  Low
  NextTo
  NoLbl
} derive(Eq, Debug)

///|
pub impl Show for TickLblPos with fn output(self, logger) {
  match self {
    High => logger.write_string("High")
    Low => logger.write_string("Low")
    NextTo => logger.write_string("NextTo")
    NoLbl => logger.write_string("NoLbl")
  }
}

///|
/// Parse `TickLblPos` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn TickLblPos::from_xml(s : String) -> TickLblPos? {
  match s {
    "high" => Some(High)
    "low" => Some(Low)
    "nextTo" => Some(NextTo)
    "none" => Some(NoLbl)
    _ => None
  }
}

///|
/// Serialise `TickLblPos` back to the OOXML attribute string.
pub fn TickLblPos::to_xml(self : TickLblPos) -> String {
  match self {
    High => "high"
    Low => "low"
    NextTo => "nextTo"
    NoLbl => "none"
  }
}

///|
/// `<c:crosses val="…"/>` (ST_Crosses).
///
/// - `AutoZero` (`val="autoZero"`) — paired axis crosses at zero (default).
/// - `Min` (`val="min"`) — at the minimum value.
/// - `Max` (`val="max"`) — at the maximum value.
pub(all) enum Crosses {
  AutoZero
  Min
  Max
} derive(Eq, Debug)

///|
pub impl Show for Crosses with fn output(self, logger) {
  match self {
    AutoZero => logger.write_string("AutoZero")
    Min => logger.write_string("Min")
    Max => logger.write_string("Max")
  }
}

///|
/// Parse `Crosses` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn Crosses::from_xml(s : String) -> Crosses? {
  match s {
    "autoZero" => Some(AutoZero)
    "min" => Some(Min)
    "max" => Some(Max)
    _ => None
  }
}

///|
/// Serialise `Crosses` back to the OOXML attribute string.
pub fn Crosses::to_xml(self : Crosses) -> String {
  match self {
    AutoZero => "autoZero"
    Min => "min"
    Max => "max"
  }
}

///|
/// `<c:numFmt formatCode="…" sourceLinked="…"/>` (CT_NumFmt).
/// Unusually for the chart schema, the data lives in attributes on
/// `<c:numFmt>` itself rather than `val="…"` on inner children.
///
/// - `format_code` — `formatCode` attribute — REQUIRED in the schema. The
///   default "General" is a sensible fallback if the source omits it (which
///   is non-conforming but tolerated).
/// - `source_linked` — `sourceLinked` attribute — optional Bool indicating
///   whether the format code follows the source data's format.
pub(all) struct NumFmt {
  format_code : String
  source_linked : Bool?
} derive(Eq, Debug)

///|
pub impl Show for NumFmt with fn output(self, logger) {
  logger.write_string("NumFmt(")
  logger.write_string(self.format_code)
  logger.write_string(")")
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:catAx>` / `<c:valAx>` / `<c:dateAx>` /
/// `<c:serAx>` element into a typed `AxisCore`. Raises `Malformed`
/// if the schema-required `<c:axId>` leaf is absent — the rest of
/// the spec-required leaves (`<c:scaling>`, `<c:axPos>`,
/// `<c:crossAx>`) are stored optional so leniently-built fixtures
/// round-trip cleanly.
fn parse_axis_core(el : @xml.XmlElement) -> AxisCore raise ChartError {
  let mut ax_id : Int? = None
  let mut scaling : Scaling? = None
  let mut delete : Bool? = None
  let mut ax_pos : AxPos? = None
  let mut major_gridlines : @xml.XmlElement? = None
  let mut minor_gridlines : @xml.XmlElement? = None
  let mut title : ChartTitle? = None
  let mut num_fmt : NumFmt? = None
  let mut major_tick_mark : TickMark? = None
  let mut minor_tick_mark : TickMark? = None
  let mut tick_lbl_pos : TickLblPos? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut tx_pr : @xml.XmlElement? = None
  let mut cross_ax : Int? = None
  let mut crosses : Crosses? = None
  let mut crosses_at : String? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "axId" => ax_id = val_int(c)
            "scaling" => scaling = Some(parse_scaling(c))
            "delete" => delete = val_bool(c)
            "axPos" => ax_pos = val_string(c).bind(AxPos::from_xml)
            "majorGridlines" => major_gridlines = Some(c)
            "minorGridlines" => minor_gridlines = Some(c)
            "title" => title = Some(parse_chart_title(c))
            "numFmt" => num_fmt = Some(parse_num_fmt(c))
            "majorTickMark" =>
              major_tick_mark = val_string(c).bind(TickMark::from_xml)
            "minorTickMark" =>
              minor_tick_mark = val_string(c).bind(TickMark::from_xml)
            "tickLblPos" =>
              tick_lbl_pos = val_string(c).bind(TickLblPos::from_xml)
            "spPr" => sp_pr = Some(c)
            "txPr" => tx_pr = Some(c)
            "crossAx" => cross_ax = val_int(c)
            "crosses" => crosses = val_string(c).bind(Crosses::from_xml)
            "crossesAt" => crosses_at = val_string(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let id = match ax_id {
    Some(n) => n
    None =>
      raise Malformed(
        "<c:" + el.name.local_name + "> is missing required <c:axId>",
      )
  }
  {
    ax_id: id,
    scaling,
    delete,
    ax_pos,
    major_gridlines,
    minor_gridlines,
    title,
    num_fmt,
    major_tick_mark,
    minor_tick_mark,
    tick_lbl_pos,
    sp_pr,
    tx_pr,
    cross_ax,
    crosses,
    crosses_at,
    extension,
  }
}

///|
fn parse_scaling(el : @xml.XmlElement) -> Scaling {
  let mut log_base : String? = None
  let mut orientation : Orientation? = None
  let mut max : String? = None
  let mut min : String? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "logBase" => log_base = val_string(c)
            "orientation" =>
              orientation = val_string(c).bind(Orientation::from_xml)
            "max" => max = val_string(c)
            "min" => min = val_string(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { log_base, orientation, max, min, extension, }
}

///|
fn parse_num_fmt(el : @xml.XmlElement) -> NumFmt {
  let mut format_code : String = "General"
  let mut source_linked : Bool? = None
  for kv in el.attributes {
    if kv.0.local_name == "formatCode" {
      format_code = kv.1
    } else if kv.0.local_name == "sourceLinked" {
      source_linked = match kv.1 {
        "1" | "true" => Some(true)
        "0" | "false" => Some(false)
        _ => None
      }
    }
  }
  { format_code, source_linked, }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit an axis element (`<c:catAx>` / `<c:valAx>` / `<c:dateAx>` /
/// `<c:serAx>`). Child order follows the ECMA-376 schema:
///   axId → scaling → delete → axPos → majorGridlines → minorGridlines
///   → title → numFmt → majorTickMark → minorTickMark → tickLblPos
///   → spPr → txPr → crossAx → crosses → crossesAt → extension.
fn write_axis(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  axis : Axis,
) -> Unit raise @xml.XmlError {
  let local_name = axis.local_name()
  let core = match axis {
    ValAx(c) | CatAx(c) | DateAx(c) | SerAx(c) => c
  }
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  emit_val_int(w, "axId", core.ax_id)
  match core.scaling {
    Some(s) => write_scaling(w, ctx, s)
    None => ()
  }
  match core.delete {
    Some(b) => emit_val_bool(w, "delete", b)
    None => ()
  }
  match core.ax_pos {
    Some(p) => emit_val_string(w, "axPos", p.to_xml())
    None => ()
  }
  match core.major_gridlines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match core.minor_gridlines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match core.title {
    Some(t) => write_chart_title(w, ctx, t)
    None => ()
  }
  match core.num_fmt {
    Some(nf) => write_num_fmt(w, nf)
    None => ()
  }
  match core.major_tick_mark {
    Some(t) => emit_val_string(w, "majorTickMark", t.to_xml())
    None => ()
  }
  match core.minor_tick_mark {
    Some(t) => emit_val_string(w, "minorTickMark", t.to_xml())
    None => ()
  }
  match core.tick_lbl_pos {
    Some(p) => emit_val_string(w, "tickLblPos", p.to_xml())
    None => ()
  }
  match core.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match core.tx_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match core.cross_ax {
    Some(n) => emit_val_int(w, "crossAx", n)
    None => ()
  }
  match core.crosses {
    Some(c) => emit_val_string(w, "crosses", c.to_xml())
    None => ()
  }
  match core.crosses_at {
    Some(s) => emit_val_string(w, "crossesAt", s)
    None => ()
  }
  for ext in core.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_scaling(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  s : Scaling,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "scaling"))
  match s.log_base {
    Some(v) => emit_val_string(w, "logBase", v)
    None => ()
  }
  match s.orientation {
    Some(o) => emit_val_string(w, "orientation", o.to_xml())
    None => ()
  }
  match s.max {
    Some(v) => emit_val_string(w, "max", v)
    None => ()
  }
  match s.min {
    Some(v) => emit_val_string(w, "min", v)
    None => ()
  }
  for ext in s.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_num_fmt(w : @xml.XmlWriter, nf : NumFmt) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "numFmt"))
  w.attribute(@xml.QName::unqualified("formatCode"), nf.format_code)
  match nf.source_linked {
    Some(b) =>
      w.attribute(
        @xml.QName::unqualified("sourceLinked"),
        if b {
          "1"
        } else {
          "0"
        },
      )
    None => ()
  }
  w.end_element()
}
