// DrawingML effect list — `<a:effectLst>` (ECMA-376 §20.1.8).
//
// An effect list carries up to eight effects in a fixed source order:
//   blur → fillOverlay → glow → innerShdw → outerShdw → prstShdw →
//   reflection → softEdge
// Each child is optional. Real PPTX almost always uses just one or two
// (typically `outerShdw` + `glow` for emphasis effects).
//
// Phase 3e4 introduces the typed model + `parse_effect_list`, and wires
// `effects : EffectList?` into auto-shape / picture / connector and into
// the run-level `RunProperties`.
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
} derive(Eq, Debug)

///|
pub fn EffectList::empty() -> EffectList {
  {
    blur: None,
    glow: None,
    inner_shadow: None,
    outer_shadow: None,
    preset_shadow: None,
    reflection: None,
    soft_edge: None,
  }
}

///|
/// Errors raised by `parse_effect_list`.
pub(all) suberror EffectError {
  /// Schema violated — missing required attribute or required colour.
  MalformedEffect(String)
  /// A nested colour child raised `ColorError`.
  EffectColorFailure(String)
} derive(Eq, Debug)

///|
pub impl Show for EffectError with output(self, logger) {
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
  while true {
    let ev = effect_next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != drawing_ns {
          effect_skip_subtree(r)
          continue
        }
        match child.local_name {
          "blur" => {
            blur = Some(parse_blur(attrs))
            effect_skip_subtree(r)
          }
          "glow" => glow = Some(parse_glow(r, attrs))
          "innerShdw" => inner_shadow = Some(parse_inner_shadow(r, attrs))
          "outerShdw" => outer_shadow = Some(parse_outer_shadow(r, attrs))
          "prstShdw" => preset_shadow = Some(parse_preset_shadow(r, attrs))
          "reflection" => {
            reflection = Some(parse_reflection(attrs))
            effect_skip_subtree(r)
          }
          "softEdge" => {
            soft_edge = Some({ rad: require_emu(attrs, "rad", "softEdge") })
            effect_skip_subtree(r)
          }
          // fillOverlay — recognised but not yet modelled; drop.
          _ => effect_skip_subtree(r)
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
  }
}

// --- individual effect parsers ---

///|
fn parse_blur(attrs : Array[(@xml.QName, String)]) -> Blur raise EffectError {
  let rad = require_emu(attrs, "rad", "blur")
  let grow = effect_bool_attr_opt(attrs, "grow")
  { rad, grow }
}

///|
fn parse_glow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Glow raise EffectError {
  let rad = require_emu(attrs, "rad", "glow")
  let color = read_first_color(r, "glow")
  { rad, color }
}

///|
fn parse_inner_shadow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> InnerShadow raise EffectError {
  let blur_rad = require_emu(attrs, "blurRad", "innerShdw")
  let dist = require_emu(attrs, "dist", "innerShdw")
  let dir = require_angle(attrs, "dir", "innerShdw")
  let color = read_first_color(r, "innerShdw")
  { blur_rad, dist, dir, color }
}

///|
fn parse_outer_shadow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> OuterShadow raise EffectError {
  let blur_rad = require_emu(attrs, "blurRad", "outerShdw")
  let dist = require_emu(attrs, "dist", "outerShdw")
  let dir = require_angle(attrs, "dir", "outerShdw")
  let sx = effect_pct_attr_opt(attrs, "sx")
  let sy = effect_pct_attr_opt(attrs, "sy")
  let kx = effect_angle_attr_opt(attrs, "kx")
  let ky = effect_angle_attr_opt(attrs, "ky")
  let alignment = effect_enum_attr_opt(attrs, "algn", RectAlignment::from_xml)
  let rotate_with_shape = effect_bool_attr_opt(attrs, "rotWithShape")
  let color = read_first_color(r, "outerShdw")
  { blur_rad, dist, dir, sx, sy, kx, ky, alignment, rotate_with_shape, color }
}

///|
fn parse_preset_shadow(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> PresetShadow raise EffectError {
  let preset = require_string_attr(attrs, "prst", "prstShdw")
  let dist = require_emu(attrs, "dist", "prstShdw")
  let dir = require_angle(attrs, "dir", "prstShdw")
  let color = read_first_color(r, "prstShdw")
  { preset, dist, dir, color }
}

///|
fn parse_reflection(attrs : Array[(@xml.QName, String)]) -> Reflection {
  {
    blur_rad: effect_emu_attr_opt(attrs, "blurRad"),
    st_a: effect_pct_attr_opt(attrs, "stA"),
    st_pos: effect_pct_attr_opt(attrs, "stPos"),
    end_a: effect_pct_attr_opt(attrs, "endA"),
    end_pos: effect_pct_attr_opt(attrs, "endPos"),
    dist: effect_emu_attr_opt(attrs, "dist"),
    dir: effect_angle_attr_opt(attrs, "dir"),
    fade_dir: effect_angle_attr_opt(attrs, "fadeDir"),
    sx: effect_pct_attr_opt(attrs, "sx"),
    sy: effect_pct_attr_opt(attrs, "sy"),
    kx: effect_angle_attr_opt(attrs, "kx"),
    ky: effect_angle_attr_opt(attrs, "ky"),
    alignment: effect_enum_attr_opt(attrs, "algn", RectAlignment::from_xml),
    rotate_with_shape: effect_bool_attr_opt(attrs, "rotWithShape"),
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
    let ev = effect_next_event(r)
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
          effect_skip_subtree(r)
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

// --- attribute helpers ---

///|
fn require_emu(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> @units.Emu raise EffectError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_effect_int64(kv.1) {
        Some(n) => return @units.Emu(n)
        None =>
          raise MalformedEffect(
            on + " attribute " + name + " is not an integer: " + kv.1,
          )
      }
    }
  }
  raise MalformedEffect(on + " is missing required attribute: " + name)
}

///|
fn require_angle(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> @units.Angle raise EffectError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_effect_int(kv.1) {
        Some(n) => return @units.Angle::from_ooxml(n)
        None =>
          raise MalformedEffect(
            on + " attribute " + name + " is not an integer: " + kv.1,
          )
      }
    }
  }
  raise MalformedEffect(on + " is missing required attribute: " + name)
}

///|
fn require_string_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> String raise EffectError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  raise MalformedEffect(on + " is missing required attribute: " + name)
}

///|
fn effect_emu_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_effect_int64(kv.1) {
        Some(n) => return Some(@units.Emu(n))
        None => return None
      }
    }
  }
  None
}

///|
fn effect_angle_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Angle? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_effect_int(kv.1) {
        Some(n) => return Some(@units.Angle::from_ooxml(n))
        None => return None
      }
    }
  }
  None
}

///|
fn effect_pct_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_effect_int(kv.1) {
        Some(n) => return Some(@units.Percentage::from_ooxml(n))
        None => return None
      }
    }
  }
  None
}

///|
fn effect_bool_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Bool? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return match kv.1 {
        "1" | "true" => Some(true)
        "0" | "false" => Some(false)
        _ => None
      }
    }
  }
  None
}

///|
fn[T] effect_enum_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
  from_xml : (String) -> T?,
) -> T? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return from_xml(kv.1)
    }
  }
  None
}

// --- xml helpers (effect-local to avoid clashes with sibling parsers) ---

///|
fn effect_next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise EffectError {
  let event = r.next() catch {
    e => raise MalformedEffect("xml error: " + e.to_string())
  }
  match event {
    Some(e) => e
    None => raise MalformedEffect("unexpected end of input inside effect")
  }
}

///|
fn effect_skip_subtree(r : @xml.XmlReader) -> Unit raise EffectError {
  let mut depth = 1
  while depth > 0 {
    let ev = effect_next_event(r)
    match ev {
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => depth = depth - 1
      _ => ()
    }
  }
}

///|
fn parse_effect_int(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign = 1
  if chars[0] == '-' {
    sign = -1
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut acc = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(acc * sign)
}

///|
fn parse_effect_int64(s : String) -> Int64? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign : Int64 = 1L
  if chars[0] == '-' {
    sign = -1L
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut acc : Int64 = 0L
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10L + (c.to_int() - '0'.to_int()).to_int64()
    i = i + 1
  }
  Some(acc * sign)
}
