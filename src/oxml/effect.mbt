// DrawingML effect list — `<a:effectLst>` (ECMA-376 §20.1.8).
//
// An effect list carries up to eight effects in a fixed source order:
//   blur → fillOverlay → glow → innerShdw → outerShdw → prstShdw →
//   reflection → softEdge
// Each child is optional. Real PPTX almost always uses just one or two
// (typically `outerShdw` + `glow` for emphasis effects).
//
// The typed model + `parse_effect_list` wires `effects : EffectList?`
// into auto-shape / picture / connector via `<p:spPr>`. Run-level
// effects on `<a:rPr>` are deferred — they exist in the spec but are
// rare in practice; surface them when a real fixture demands it.
//
// The richer `<a:effectDag>` element (effect graph with custom node
// composition) is rare in real-world PPTX; we don't model it yet — its
// presence is silently skipped so the surrounding shape still parses.

///|
/// Rectangular alignment used by `outerShdw` / `reflection` for the
/// "alignment point" inside the bounding rect. Same nine values as
/// `TileAlignment`, kept distinct so the two contexts don't get
/// conflated.
pub(all) enum RectAlignment {
  RectTopLeft // "tl"
  RectTop // "t"
  RectTopRight // "tr"
  RectLeft // "l"
  RectCenter // "ctr"
  RectRight // "r"
  RectBottomLeft // "bl"
  RectBottom // "b"
  RectBottomRight // "br"
} derive(Eq, Debug)

///|
/// Parse `RectAlignment` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn RectAlignment::from_xml(s : String) -> RectAlignment? {
  match s {
    "tl" => Some(RectTopLeft)
    "t" => Some(RectTop)
    "tr" => Some(RectTopRight)
    "l" => Some(RectLeft)
    "ctr" => Some(RectCenter)
    "r" => Some(RectRight)
    "bl" => Some(RectBottomLeft)
    "b" => Some(RectBottom)
    "br" => Some(RectBottomRight)
    _ => None
  }
}

///|
/// `<a:blur rad="…" grow="0"/>` — Gaussian blur.
pub(all) struct Blur {
  rad : @units.Emu
  grow : Bool?
} derive(Eq, Debug)

///|
/// `<a:glow rad="…">…color…</a:glow>` — outer glow.
pub(all) struct Glow {
  rad : @units.Emu
  color : Color
} derive(Eq, Debug)

///|
/// `<a:innerShdw blurRad="…" dist="…" dir="…">…color…</a:innerShdw>`
pub(all) struct InnerShadow {
  blur_rad : @units.Emu
  dist : @units.Emu
  dir : @units.Angle
  color : Color
} derive(Eq, Debug)

///|
/// `<a:outerShdw blurRad="…" dist="…" dir="…" sx="…" sy="…" kx="…"
///               ky="…" algn="…" rotWithShape="…">…color…</a:outerShdw>`
pub(all) struct OuterShadow {
  blur_rad : @units.Emu
  dist : @units.Emu
  dir : @units.Angle
  sx : @units.Percentage?
  sy : @units.Percentage?
  kx : @units.Angle?
  ky : @units.Angle?
  alignment : RectAlignment?
  rotate_with_shape : Bool?
  color : Color
} derive(Eq, Debug)

///|
/// `<a:prstShdw prst="…" dist="…" dir="…">…color…</a:prstShdw>` — a
/// preset-named shadow. PowerPoint exposes 20 named presets in
/// `ST_PresetShadowVal`. Kept as a `String` so unknown presets
/// round-trip.
pub(all) struct PresetShadow {
  preset : String
  dist : @units.Emu
  dir : @units.Angle
  color : Color
} derive(Eq, Debug)

///|
/// `<a:softEdge rad="…"/>` — fades the shape edge inward.
pub(all) struct SoftEdge {
  rad : @units.Emu
} derive(Eq, Debug)

///|
/// `<a:reflection …/>` — mirrored reflection beneath the shape. Many
/// optional attributes; most real PPTX uses just a few.
pub(all) struct Reflection {
  blur_rad : @units.Emu?
  st_a : @units.Percentage?
  st_pos : @units.Percentage?
  end_a : @units.Percentage?
  end_pos : @units.Percentage?
  dist : @units.Emu?
  dir : @units.Angle?
  fade_dir : @units.Angle?
  sx : @units.Percentage?
  sy : @units.Percentage?
  kx : @units.Angle?
  ky : @units.Angle?
  alignment : RectAlignment?
  rotate_with_shape : Bool?
} derive(Eq, Debug)

///|
/// Parsed `<a:effectLst>` — every child is optional; absent → `None`.
/// The `<a:fillOverlay>` element is recognised but not currently
/// modelled (it carries a nested `Fill` plus a blend mode); we drop it
/// rather than block parsing for now.
pub(all) struct EffectList {
  blur : Blur?
  glow : Glow?
  inner_shadow : InnerShadow?
  outer_shadow : OuterShadow?
  preset_shadow : PresetShadow?
  reflection : Reflection?
  soft_edge : SoftEdge?
  /// Lossless preservation (ADR-004): `<a:fillOverlay>` (which carries a
  /// nested `Fill` plus blend mode and is not yet typed), `<a:extLst>`,
  /// and foreign-namespace `<a:effectLst>` children.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Errors raised by `parse_effect_list`.
pub(all) suberror EffectError {
  /// Schema violated — missing required attribute or required colour.
  MalformedEffect(String)
  /// A nested colour child raised `ColorError`.
  EffectColorFailure(String)
} derive(Eq, Debug)

///|
pub impl Show for EffectError with fn output(self, logger) {
  match self {
    MalformedEffect(s) => {
      logger.write_string("MalformedEffect(")
      logger.write_object(s)
      logger.write_string(")")
    }
    EffectColorFailure(s) => {
      logger.write_string("EffectColorFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}

///|
/// Parse an `<a:effectLst>` element. `r` is positioned just after the
/// StartElement and is consumed through the matching EndElement.
pub fn parse_effect_list(r : @xml.XmlReader) -> EffectList raise EffectError {
  let mut blur : Blur? = None
  let mut glow : Glow? = None
  let mut inner_shadow : InnerShadow? = None
  let mut outer_shadow : OuterShadow? = None
  let mut preset_shadow : PresetShadow? = None
  let mut reflection : Reflection? = None
  let mut soft_edge : SoftEdge? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r) catch { e => raise MalformedEffect(e.to_string()) }
    match ev {
      StartElement(child, attrs) =>
        if child.uri != drawing_ns {
          extension.push(
            collect_subtree(r, child, attrs) catch {
              e => raise MalformedEffect(e.to_string())
            },
          )
        } else {
          match child.local_name {
            "blur" => {
              blur = Some(parse_blur(attrs))
              skip_subtree(r) catch {
                e => raise MalformedEffect(e.to_string())
              }
            }
            "glow" => glow = Some(parse_glow(r, attrs))
            "innerShdw" => inner_shadow = Some(parse_inner_shadow(r, attrs))
            "outerShdw" => outer_shadow = Some(parse_outer_shadow(r, attrs))
            "prstShdw" => preset_shadow = Some(parse_preset_shadow(r, attrs))
            "reflection" => {
              reflection = Some(parse_reflection(attrs))
              skip_subtree(r) catch {
                e => raise MalformedEffect(e.to_string())
              }
            }
            "softEdge" => {
              let rad = require_emu(attrs, "rad", "softEdge") catch {
                e => raise MalformedEffect(e.to_string())
              }
              soft_edge = Some({ rad, })
              skip_subtree(r) catch {
                e => raise MalformedEffect(e.to_string())
              }
            }
            // fillOverlay (not yet modelled), extLst, etc. survive
            // round-trip via `extension`.
            _ =>
              extension.push(
                collect_subtree(r, child, attrs) catch {
                  e => raise MalformedEffect(e.to_string())
                },
              )
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    blur,
    glow,
    inner_shadow,
    outer_shadow,
    preset_shadow,
    reflection,
    soft_edge,
    extension,
  }
}

// --- individual effect parsers (raise XmlReadError; lifted at call site) ---

///|
/// EMU coordinate attribute that defaults to 0 when absent. ECMA-376 marks
/// the shadow / blur / glow coordinates (`blurRad` / `dist` / `rad`)
/// optional with a default of 0, so a minimal `<a:outerShdw blurRad="…"/>`
/// (or a bare `<a:blur/>`) must parse rather than raise — required for the
/// run-level `<a:effectLst>` lift (F3) where such minimal forms appear and
/// previously round-tripped via `extension`.
fn emu_attr_or_zero(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu {
  emu_attr_opt(attrs, name).unwrap_or(@units.Emu(0L))
}

///|
/// Angle attribute that defaults to 0 when absent — the shadow `dir`
/// default per ECMA-376.
fn angle_attr_or_zero(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Angle {
  angle_attr_opt(attrs, name).unwrap_or(@units.Angle(0.0))
}

///|
fn parse_blur(attrs : Array[(@xml.QName, String)]) -> Blur {
  let rad = emu_attr_or_zero(attrs, "rad")
  let grow = bool_attr_opt(attrs, "grow")
  { rad, grow }
}

///|
fn parse_glow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Glow raise EffectError {
  let rad = emu_attr_or_zero(attrs, "rad")
  let color = read_first_color(r, "glow")
  { rad, color }
}

///|
fn parse_inner_shadow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> InnerShadow raise EffectError {
  let blur_rad = emu_attr_or_zero(attrs, "blurRad")
  let dist = emu_attr_or_zero(attrs, "dist")
  let dir = angle_attr_or_zero(attrs, "dir")
  let color = read_first_color(r, "innerShdw")
  { blur_rad, dist, dir, color }
}

///|
fn parse_outer_shadow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> OuterShadow raise EffectError {
  let blur_rad = emu_attr_or_zero(attrs, "blurRad")
  let dist = emu_attr_or_zero(attrs, "dist")
  let dir = angle_attr_or_zero(attrs, "dir")
  let sx = pct_attr_opt(attrs, "sx")
  let sy = pct_attr_opt(attrs, "sy")
  let kx = angle_attr_opt(attrs, "kx")
  let ky = angle_attr_opt(attrs, "ky")
  let alignment = enum_attr_opt(attrs, "algn", RectAlignment::from_xml)
  let rotate_with_shape = bool_attr_opt(attrs, "rotWithShape")
  let color = read_first_color(r, "outerShdw")
  { blur_rad, dist, dir, sx, sy, kx, ky, alignment, rotate_with_shape, color }
}

///|
fn parse_preset_shadow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> PresetShadow raise EffectError {
  let preset = require_attr(attrs, "prst", "prstShdw") catch {
    e => raise MalformedEffect(e.to_string())
  }
  let dist = emu_attr_or_zero(attrs, "dist")
  let dir = angle_attr_or_zero(attrs, "dir")
  let color = read_first_color(r, "prstShdw")
  { preset, dist, dir, color }
}

///|
fn parse_reflection(attrs : Array[(@xml.QName, String)]) -> Reflection {
  {
    blur_rad: emu_attr_opt(attrs, "blurRad"),
    st_a: pct_attr_opt(attrs, "stA"),
    st_pos: pct_attr_opt(attrs, "stPos"),
    end_a: pct_attr_opt(attrs, "endA"),
    end_pos: pct_attr_opt(attrs, "endPos"),
    dist: emu_attr_opt(attrs, "dist"),
    dir: angle_attr_opt(attrs, "dir"),
    fade_dir: angle_attr_opt(attrs, "fadeDir"),
    sx: pct_attr_opt(attrs, "sx"),
    sy: pct_attr_opt(attrs, "sy"),
    kx: angle_attr_opt(attrs, "kx"),
    ky: angle_attr_opt(attrs, "ky"),
    alignment: enum_attr_opt(attrs, "algn", RectAlignment::from_xml),
    rotate_with_shape: bool_attr_opt(attrs, "rotWithShape"),
  }
}

///|
/// Read the first colour-choice child inside an effect that requires a
/// colour. Raises `MalformedEffect` if no colour child is present.
fn read_first_color(
  r : @xml.XmlReader,
  context : String,
) -> Color raise EffectError {
  let mut found : Color? = None
  while true {
    let ev = next_event(r) catch { e => raise MalformedEffect(e.to_string()) }
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == drawing_ns {
          let color = parse_color_element(r, child, child_attrs) catch {
            e => raise EffectColorFailure(context + ": " + e.to_string())
          }
          if found is None {
            found = Some(color)
          }
        } else {
          skip_subtree(r) catch {
            e => raise MalformedEffect(e.to_string())
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match found {
    Some(c) => c
    None => raise MalformedEffect(context + " has no colour child")
  }
}
