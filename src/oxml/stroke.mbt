// Unified DrawingML line (stroke) model.
//
// `<a:ln>` (ECMA-376 §20.1.2.2.24) is the line / outline definition that
// shows up on every shape's `<p:spPr>`, every connector, every text run
// underline, and every table cell border. The element carries four
// attributes (width / cap / compound / alignment) and a handful of
// optional child elements: a fill, a dash style, a line-join style, and
// up to two arrowheads.
//
// Phase 3e3 introduces the typed model and `parse_stroke`. Later phases
// wire `stroke : Option<Stroke>` into auto-shape / connector / picture
// records so consumers can pattern-match on outline shape.

///|
/// Line end cap (`ST_LineCap`, §20.1.10.30).
pub(all) enum LineCap {
  CapFlat // "flat"
  CapSquare // "sq"
  CapRound // "rnd"
} derive(Eq, Debug)

///|
pub fn LineCap::from_xml(s : String) -> LineCap? {
  match s {
    "flat" => Some(CapFlat)
    "sq" => Some(CapSquare)
    "rnd" => Some(CapRound)
    _ => None
  }
}

///|
/// Compound line type (`ST_CompoundLine`, §20.1.10.15).
pub(all) enum CompoundLine {
  CmpdSingle // "sng"
  CmpdDouble // "dbl"
  CmpdThickThin // "thickThin"
  CmpdThinThick // "thinThick"
  CmpdTriple // "tri"
} derive(Eq, Debug)

///|
pub fn CompoundLine::from_xml(s : String) -> CompoundLine? {
  match s {
    "sng" => Some(CmpdSingle)
    "dbl" => Some(CmpdDouble)
    "thickThin" => Some(CmpdThickThin)
    "thinThick" => Some(CmpdThinThick)
    "tri" => Some(CmpdTriple)
    _ => None
  }
}

///|
/// Pen alignment (`ST_PenAlignment`, §20.1.10.46). `AlignCenter` is the
/// spec default for the missing-attribute case.
pub(all) enum PenAlignment {
  AlignPenCenter // "ctr"
  AlignPenInset // "in"
} derive(Eq, Debug)

///|
pub fn PenAlignment::from_xml(s : String) -> PenAlignment? {
  match s {
    "ctr" => Some(AlignPenCenter)
    "in" => Some(AlignPenInset)
    _ => None
  }
}

///|
/// Preset dash style (`ST_PresetLineDashVal`, §20.1.10.49). Covers
/// every value the spec enumerates; rare custom dashes (`<a:custDash>`)
/// are skipped by the parser for now.
pub(all) enum DashStyle {
  DashSolid // "solid"
  DashDot // "dot"
  DashDash // "dash"
  DashLgDash // "lgDash"
  DashDashDot // "dashDot"
  DashLgDashDot // "lgDashDot"
  DashLgDashDotDot // "lgDashDotDot"
  DashSysDash // "sysDash"
  DashSysDot // "sysDot"
  DashSysDashDot // "sysDashDot"
  DashSysDashDotDot // "sysDashDotDot"
} derive(Eq, Debug)

///|
pub fn DashStyle::from_xml(s : String) -> DashStyle? {
  match s {
    "solid" => Some(DashSolid)
    "dot" => Some(DashDot)
    "dash" => Some(DashDash)
    "lgDash" => Some(DashLgDash)
    "dashDot" => Some(DashDashDot)
    "lgDashDot" => Some(DashLgDashDot)
    "lgDashDotDot" => Some(DashLgDashDotDot)
    "sysDash" => Some(DashSysDash)
    "sysDot" => Some(DashSysDot)
    "sysDashDot" => Some(DashSysDashDot)
    "sysDashDotDot" => Some(DashSysDashDotDot)
    _ => None
  }
}

///|
/// Line join style (`<a:round/>` / `<a:bevel/>` / `<a:miter lim="…"/>`).
/// The miter variant carries the optional limit attribute as a
/// `Percentage` (1/1000-percent OOXML units).
pub(all) enum LineJoin {
  JoinRound
  JoinBevel
  JoinMiter(@units.Percentage?)
} derive(Eq, Debug)

///|
/// Arrowhead shape (`ST_LineEndType`, §20.1.10.27).
pub(all) enum ArrowType {
  ArrowNone // "none"
  ArrowTriangle // "triangle"
  ArrowStealth // "stealth"
  ArrowDiamond // "diamond"
  ArrowOval // "oval"
  ArrowArrow // "arrow"
} derive(Eq, Debug)

///|
pub fn ArrowType::from_xml(s : String) -> ArrowType? {
  match s {
    "none" => Some(ArrowNone)
    "triangle" => Some(ArrowTriangle)
    "stealth" => Some(ArrowStealth)
    "diamond" => Some(ArrowDiamond)
    "oval" => Some(ArrowOval)
    "arrow" => Some(ArrowArrow)
    _ => None
  }
}

///|
/// Arrow size category (`ST_LineEndWidth` / `ST_LineEndLength`,
/// §20.1.10.26 / §20.1.10.25). Both axes use the same enum.
pub(all) enum ArrowSize {
  SizeSmall // "sm"
  SizeMedium // "med"
  SizeLarge // "lg"
} derive(Eq, Debug)

///|
pub fn ArrowSize::from_xml(s : String) -> ArrowSize? {
  match s {
    "sm" => Some(SizeSmall)
    "med" => Some(SizeMedium)
    "lg" => Some(SizeLarge)
    _ => None
  }
}

///|
/// One arrowhead (`<a:headEnd>` or `<a:tailEnd>`). `type` is the only
/// required attribute; `width` and `length` default to medium per spec
/// (we keep them as `Option` so callers can distinguish absent from
/// explicit-medium).
pub(all) struct ArrowEnd {
  arrow_type : ArrowType
  width : ArrowSize?
  length : ArrowSize?
} derive(Eq, Debug)

///|
/// Parsed `<a:ln>` line definition.
///
/// Every field is `Option` because OOXML treats lines as additively
/// inherited (shape line → theme → master → defaults); a `None` means
/// "inherit from the next layer up". The inheritance resolver lives a
/// layer above this parser.
pub(all) struct Stroke {
  /// `w` — line width in EMU.
  width : @units.Emu?
  /// `cap` — line end cap.
  cap : LineCap?
  /// `cmpd` — compound line type.
  compound : CompoundLine?
  /// `algn` — pen alignment.
  alignment : PenAlignment?
  /// Line fill (`<a:noFill>` / `<a:solidFill>` / `<a:gradFill>` /
  /// `<a:pattFill>` — `<a:blipFill>` is legal but virtually never used
  /// on lines). Reuses the unified `@oxml.Fill` from 3e2.
  fill : Fill?
  /// `<a:prstDash val="…"/>`. The rarely-seen `<a:custDash>` variant is
  /// silently skipped for now.
  dash : DashStyle?
  /// Line-join geometry.
  join : LineJoin?
  /// `<a:headEnd …/>` — arrow on the start point.
  head_end : ArrowEnd?
  /// `<a:tailEnd …/>` — arrow on the end point.
  tail_end : ArrowEnd?
  /// Lossless preservation (ADR-004): `<a:custDash>`, `<a:extLst>`, and
  /// foreign-namespace `<a:ln>` children.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Errors raised by `parse_stroke`.
pub(all) suberror StrokeError {
  MalformedStroke(String)
  FillFailure(String)
} derive(Eq, Debug)

///|
pub impl Show for StrokeError with fn output(self, logger) {
  match self {
    MalformedStroke(s) => {
      logger.write_string("MalformedStroke(")
      logger.write_object(s)
      logger.write_string(")")
    }
    FillFailure(s) => {
      logger.write_string("FillFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}

///|
/// Parse an `<a:ln>` element. `attrs` are the attributes of the
/// already-consumed StartElement; `r` is positioned just after that
/// StartElement and is consumed through the matching EndElement.
pub fn parse_stroke(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Stroke raise StrokeError {
  let width = emu_attr_opt(attrs, "w")
  let cap = enum_attr_opt(attrs, "cap", LineCap::from_xml)
  let compound = enum_attr_opt(attrs, "cmpd", CompoundLine::from_xml)
  let alignment = enum_attr_opt(attrs, "algn", PenAlignment::from_xml)
  let mut fill : Fill? = None
  let mut dash : DashStyle? = None
  let mut join : LineJoin? = None
  let mut head_end : ArrowEnd? = None
  let mut tail_end : ArrowEnd? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r) catch { e => raise MalformedStroke(e.to_string()) }
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != drawing_ns {
          extension.push(
            collect_subtree(r, child, child_attrs) catch {
              e => raise MalformedStroke(e.to_string())
            },
          )
        } else {
          match child.local_name {
            // Fill kinds — delegate to @oxml.parse_fill.
            "noFill" | "solidFill" | "gradFill" | "pattFill" | "blipFill" => {
              let f = parse_fill(r, child, child_attrs) catch {
                e => raise FillFailure(e.to_string())
              }
              if fill is None {
                fill = Some(f)
              }
            }
            "prstDash" => {
              dash = enum_attr_opt(child_attrs, "val", DashStyle::from_xml)
              skip_subtree(r) catch {
                e => raise MalformedStroke(e.to_string())
              }
            }
            "round" => {
              join = Some(JoinRound)
              skip_subtree(r) catch {
                e => raise MalformedStroke(e.to_string())
              }
            }
            "bevel" => {
              join = Some(JoinBevel)
              skip_subtree(r) catch {
                e => raise MalformedStroke(e.to_string())
              }
            }
            "miter" => {
              let lim = pct_attr_opt(child_attrs, "lim")
              join = Some(JoinMiter(lim))
              skip_subtree(r) catch {
                e => raise MalformedStroke(e.to_string())
              }
            }
            "headEnd" => {
              head_end = Some(parse_arrow_end(child_attrs))
              skip_subtree(r) catch {
                e => raise MalformedStroke(e.to_string())
              }
            }
            "tailEnd" => {
              tail_end = Some(parse_arrow_end(child_attrs))
              skip_subtree(r) catch {
                e => raise MalformedStroke(e.to_string())
              }
            }
            // custDash, extLst, and any other unmodelled child get
            // captured verbatim per ADR-004.
            _ =>
              extension.push(
                collect_subtree(r, child, child_attrs) catch {
                  e => raise MalformedStroke(e.to_string())
                },
              )
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    width,
    cap,
    compound,
    alignment,
    fill,
    dash,
    join,
    head_end,
    tail_end,
    extension,
  }
}

///|
fn parse_arrow_end(attrs : Array[(@xml.QName, String)]) -> ArrowEnd {
  let arrow_type = match enum_attr_opt(attrs, "type", ArrowType::from_xml) {
    Some(t) => t
    // Spec default for missing type is "none".
    None => ArrowNone
  }
  let width = enum_attr_opt(attrs, "w", ArrowSize::from_xml)
  let length = enum_attr_opt(attrs, "len", ArrowSize::from_xml)
  { arrow_type, width, length }
}
