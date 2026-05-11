// Unified DrawingML fill model.
//
// `EG_FillProperties` (ECMA-376 §20.1.10.31) is the choice group that
// appears wherever OOXML accepts a "fill": shape `<p:spPr>` body, run-
// level `<a:rPr>` (currently consumed only as solid colour — see 3d2),
// gradient-stop colours (which themselves can be filled), table cell
// backgrounds, theme `fmtScheme/fillStyleLst`, and chart series colours.
//
// Every fill is one of five wrappers:
//   * `<a:noFill/>`
//   * `<a:solidFill>` containing a single colour element
//   * `<a:gradFill>` with `<a:gsLst>` (gradient stops) + `<a:lin>` /
//     `<a:path>` for direction
//   * `<a:pattFill prst="…">` with `<a:fgClr>` and `<a:bgClr>`
//   * `<a:blipFill>` with `<a:blip>`, optional `<a:srcRect>`, and a
//     `<a:stretch>` / `<a:tile>` fill-mode child
//
// Phase 3e2 introduces the typed model and the entry-point parser
// `parse_fill`. Phase 3e3 / 3e4 reuse this for line fills and effect
// fills.

///|
/// One destination rectangle for a stretched blip fill or a fill-list
/// gradient. All four sides are 1/1000-of-percent of the destination
/// extent; negative values are valid per spec.
pub(all) struct FillRect {
  left : @units.Percentage
  top : @units.Percentage
  right : @units.Percentage
  bottom : @units.Percentage
} derive(Eq, Debug)

///|
/// Default-zero `FillRect` (the common case when `<a:fillRect/>` is
/// emitted with no attributes — the entire destination is filled).
pub fn FillRect::default() -> FillRect {
  {
    left: @units.Percentage(0.0),
    top: @units.Percentage(0.0),
    right: @units.Percentage(0.0),
    bottom: @units.Percentage(0.0),
  }
}

///|
/// Source rectangle (`<a:srcRect>`) — the crop inside the source image
/// for a blip fill. Same `Percentage` scale as `FillRect`. Distinct
/// type so the parser can keep src-vs-dst rectangles unambiguous.
pub(all) struct SrcRect {
  left : @units.Percentage
  top : @units.Percentage
  right : @units.Percentage
  bottom : @units.Percentage
} derive(Eq, Debug)

///|
pub fn SrcRect::default() -> SrcRect {
  {
    left: @units.Percentage(0.0),
    top: @units.Percentage(0.0),
    right: @units.Percentage(0.0),
    bottom: @units.Percentage(0.0),
  }
}

///|
/// Tile flip mode (`ST_TileFlipMode`). `FlipNone` is the spec default.
pub(all) enum TileFlip {
  FlipNone // "none"
  FlipX // "x"
  FlipY // "y"
  FlipXy // "xy"
} derive(Eq, Debug)

///|
pub fn TileFlip::from_xml(s : String) -> TileFlip? {
  match s {
    "none" => Some(FlipNone)
    "x" => Some(FlipX)
    "y" => Some(FlipY)
    "xy" => Some(FlipXy)
    _ => None
  }
}

///|
/// Tile alignment (`ST_RectAlignment`). Nine values per spec — the
/// anchor inside the destination box where the first tile is placed.
pub(all) enum TileAlignment {
  AlignTopLeft // "tl"
  AlignTop // "t"
  AlignTopRight // "tr"
  AlignLeft // "l"
  AlignCenter // "ctr"
  AlignRight // "r"
  AlignBottomLeft // "bl"
  AlignBottom // "b"
  AlignBottomRight // "br"
} derive(Eq, Debug)

///|
pub fn TileAlignment::from_xml(s : String) -> TileAlignment? {
  match s {
    "tl" => Some(AlignTopLeft)
    "t" => Some(AlignTop)
    "tr" => Some(AlignTopRight)
    "l" => Some(AlignLeft)
    "ctr" => Some(AlignCenter)
    "r" => Some(AlignRight)
    "bl" => Some(AlignBottomLeft)
    "b" => Some(AlignBottom)
    "br" => Some(AlignBottomRight)
    _ => None
  }
}

///|
/// `<a:tile>` attributes. All optional per spec; missing attributes
/// stay `None` so callers can distinguish "absent" from "explicitly 0".
pub(all) struct TileSpec {
  tx : @units.Emu?
  ty : @units.Emu?
  sx : @units.Percentage?
  sy : @units.Percentage?
  flip : TileFlip?
  alignment : TileAlignment?
} derive(Eq, Debug)

///|
pub fn TileSpec::default() -> TileSpec {
  { tx: None, ty: None, sx: None, sy: None, flip: None, alignment: None }
}

///|
/// Blip fill mode — either stretch with an optional clip rectangle, or
/// tile with positioning + scaling + flip + alignment.
pub(all) enum BlipFillMode {
  /// `<a:stretch>` with an optional `<a:fillRect/>` inside.
  Stretch(FillRect?)
  /// `<a:tile …/>`.
  Tile(TileSpec)
} derive(Eq, Debug)

///|
/// `<a:blipFill>` — picture / texture fill.
///
/// `embed_id` is `r:embed`, `link_id` is `r:link`. At least one is
/// required by the spec; the parser raises if both are missing.
/// `src_rect` is the optional `<a:srcRect>` crop. `fill_mode` is
/// the stretch-vs-tile child; defaults to `Stretch(None)` when the
/// `<a:blipFill>` has neither.
pub(all) struct BlipFill {
  embed_id : String
  link_id : String
  src_rect : SrcRect?
  fill_mode : BlipFillMode
} derive(Eq, Debug)

///|
/// One stop in a gradient fill.
pub(all) struct GradientStop {
  /// Stop position in `Percentage` (0% – 100%, lifted from the
  /// 1/1000-percent `pos` attribute).
  position : @units.Percentage
  color : Color
} derive(Eq, Debug)

///|
/// Gradient direction. `Linear(angle, scaled)` mirrors `<a:lin>`;
/// `Path*` mirror `<a:path path="…">` for the three accepted shapes.
pub(all) enum GradientDirection {
  /// `<a:lin ang="…" scaled="0"/>` — linear gradient at `angle`.
  /// `scaled` is `True` when the linear extent scales with the shape.
  Linear(@units.Angle, Bool)
  PathRect
  PathCircle
  PathShape
} derive(Eq, Debug)

///|
/// `<a:gradFill>` — gradient fill.
///
/// Empty `stops` is malformed per spec; the parser raises if `<a:gsLst>`
/// is missing or contains no `<a:gs>` children. `direction` defaults to
/// `Linear(Angle(0.0), False)` when the spec's directional choice is
/// absent — i.e. an unusual but legal "static" gradient.
pub(all) struct Gradient {
  stops : Array[GradientStop]
  direction : GradientDirection
  rotate_with_shape : Bool?
  flip : TileFlip?
} derive(Eq, Debug)

///|
/// `<a:pattFill>` — pattern fill (cross-hatch, dot, etc.).
pub(all) struct Pattern {
  /// `prst` — one of ~48 preset names per `ST_PresetPatternVal`.
  /// Kept as a `String` so unknown presets round-trip.
  preset : String
  fg : Color
  bg : Color
} derive(Eq, Debug)

///|
/// Top-level fill choice. Every OOXML fill site decomposes to one of
/// these five variants.
pub(all) enum Fill {
  NoFill
  SolidFill(Color)
  GradientFill(Gradient)
  PatternFill(Pattern)
  BlipFillVariant(BlipFill)
} derive(Eq, Debug)

///|
/// Errors raised by `parse_fill`.
pub(all) suberror FillError {
  /// The element is not one of `noFill` / `solidFill` / `gradFill` /
  /// `pattFill` / `blipFill`.
  UnknownFillElement(String)
  /// Schema constraint violated (missing required attribute or child).
  MalformedFill(String)
  /// A nested colour child raised `ColorError`. Payload is the wrapped
  /// description.
  ColorFailure(String)
} derive(Eq, Debug)

///|
pub impl Show for FillError with output(self, logger) {
  match self {
    UnknownFillElement(s) => {
      logger.write_string("UnknownFillElement(")
      logger.write_object(s)
      logger.write_string(")")
    }
    MalformedFill(s) => {
      logger.write_string("MalformedFill(")
      logger.write_object(s)
      logger.write_string(")")
    }
    ColorFailure(s) => {
      logger.write_string("ColorFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}

///|
/// Parse a fill-choice element. `name` is the consumed StartElement's
/// QName; `attrs` are its attributes; `r` is positioned just after the
/// StartElement and is consumed through the matching EndElement.
pub fn parse_fill(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> Fill raise FillError {
  match name.local_name {
    "noFill" => {
      fill_skip_subtree(r)
      NoFill
    }
    "solidFill" => SolidFill(parse_solid_fill_body(r))
    "gradFill" => GradientFill(parse_gradient_fill(r, attrs))
    "pattFill" => PatternFill(parse_pattern_fill(r, attrs))
    "blipFill" => BlipFillVariant(parse_blip_fill(r))
    other => raise UnknownFillElement(other)
  }
}

// --- solid fill ---

///|
fn parse_solid_fill_body(r : @xml.XmlReader) -> Color raise FillError {
  let mut found : Color? = None
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == drawing_ns {
          let color = parse_color_element(r, child, child_attrs) catch {
            e => raise ColorFailure("solidFill: " + e.to_string())
          }
          if found is None {
            found = Some(color)
          }
        } else {
          fill_skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match found {
    Some(c) => c
    None => raise MalformedFill("solidFill has no colour child")
  }
}

// --- gradient fill ---

///|
fn parse_gradient_fill(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Gradient raise FillError {
  let rotate_with_shape = parse_bool_attr_opt(attrs, "rotWithShape")
  let flip = parse_enum_attr_opt(attrs, "flip", TileFlip::from_xml)
  let stops : Array[GradientStop] = []
  let mut direction : GradientDirection = Linear(@units.Angle(0.0), false)
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, child_attrs) => {
        if child.uri != drawing_ns {
          fill_skip_subtree(r)
          continue
        }
        match child.local_name {
          "gsLst" => parse_gradient_stops(r, stops)
          "lin" => {
            let ang_raw = fill_require_attr(child_attrs, "ang", "lin")
            let ang = match parse_int_local(ang_raw) {
              Some(n) => @units.Angle::from_ooxml(n)
              None =>
                raise MalformedFill("lin ang is not an integer: " + ang_raw)
            }
            let scaled = parse_bool_attr_opt(child_attrs, "scaled").unwrap_or(
              false,
            )
            direction = Linear(ang, scaled)
            fill_skip_subtree(r)
          }
          "path" => {
            let path_raw = fill_require_attr(child_attrs, "path", "path")
            direction = match path_raw {
              "rect" => PathRect
              "circle" => PathCircle
              "shape" => PathShape
              other => raise MalformedFill("unknown gradient path: " + other)
            }
            fill_skip_subtree(r)
          }
          // tileRect — sub-rectangle; rare. Skip for now.
          _ => fill_skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  if stops.length() == 0 {
    raise MalformedFill("gradFill has no gradient stops")
  }
  { stops, direction, rotate_with_shape, flip }
}

///|
fn parse_gradient_stops(
  r : @xml.XmlReader,
  out : Array[GradientStop],
) -> Unit raise FillError {
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == drawing_ns && child.local_name == "gs" {
          let pos_raw = fill_require_attr(child_attrs, "pos", "gs")
          let position = match parse_int_local(pos_raw) {
            Some(n) => @units.Percentage::from_ooxml(n)
            None => raise MalformedFill("gs pos is not an integer: " + pos_raw)
          }
          let color = parse_first_color(r, "gradient stop")
          out.push({ position, color })
        } else {
          fill_skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
}

// --- pattern fill ---

///|
fn parse_pattern_fill(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Pattern raise FillError {
  let preset = optional_attr_local(attrs, "prst")
  let mut fg : Color? = None
  let mut bg : Color? = None
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, _) => {
        if child.uri != drawing_ns {
          fill_skip_subtree(r)
          continue
        }
        match child.local_name {
          "fgClr" => fg = Some(parse_first_color(r, "pattFill fgClr"))
          "bgClr" => bg = Some(parse_first_color(r, "pattFill bgClr"))
          _ => fill_skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  match (fg, bg) {
    (Some(f), Some(b)) => { preset, fg: f, bg: b }
    _ => raise MalformedFill("pattFill is missing fgClr or bgClr (need both)")
  }
}

// --- blip fill ---

///|
fn parse_blip_fill(r : @xml.XmlReader) -> BlipFill raise FillError {
  let mut embed_id = ""
  let mut link_id = ""
  let mut src_rect : SrcRect? = None
  let mut fill_mode : BlipFillMode = Stretch(None)
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, child_attrs) => {
        if child.uri != drawing_ns {
          fill_skip_subtree(r)
          continue
        }
        match child.local_name {
          "blip" => {
            let (e, l) = extract_blip_relationships(child_attrs)
            embed_id = e
            link_id = l
            // colour modifications & image effects nested here are
            // intentionally skipped — they belong to effects parsing.
            fill_skip_subtree(r)
          }
          "srcRect" => {
            src_rect = Some(parse_src_rect(child_attrs))
            fill_skip_subtree(r)
          }
          "stretch" => fill_mode = parse_stretch(r)
          "tile" => {
            fill_mode = Tile(parse_tile_attrs(child_attrs))
            fill_skip_subtree(r)
          }
          _ => fill_skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  if embed_id.length() == 0 && link_id.length() == 0 {
    raise MalformedFill("blipFill is missing both r:embed and r:link")
  }
  { embed_id, link_id, src_rect, fill_mode }
}

///|
fn parse_stretch(r : @xml.XmlReader) -> BlipFillMode raise FillError {
  let mut rect : FillRect? = None
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, child_attrs) => {
        if child.uri == drawing_ns && child.local_name == "fillRect" {
          rect = Some(parse_fill_rect(child_attrs))
        }
        fill_skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  Stretch(rect)
}

///|
fn parse_tile_attrs(attrs : Array[(@xml.QName, String)]) -> TileSpec {
  {
    tx: parse_emu_attr_opt(attrs, "tx"),
    ty: parse_emu_attr_opt(attrs, "ty"),
    sx: parse_percent_attr_opt_fill(attrs, "sx"),
    sy: parse_percent_attr_opt_fill(attrs, "sy"),
    flip: parse_enum_attr_opt(attrs, "flip", TileFlip::from_xml),
    alignment: parse_enum_attr_opt(attrs, "algn", TileAlignment::from_xml),
  }
}

///|
fn parse_src_rect(
  attrs : Array[(@xml.QName, String)],
) -> SrcRect raise FillError {
  {
    left: parse_percent_attr_strict(attrs, "l", "srcRect"),
    top: parse_percent_attr_strict(attrs, "t", "srcRect"),
    right: parse_percent_attr_strict(attrs, "r", "srcRect"),
    bottom: parse_percent_attr_strict(attrs, "b", "srcRect"),
  }
}

///|
fn parse_fill_rect(
  attrs : Array[(@xml.QName, String)],
) -> FillRect raise FillError {
  {
    left: parse_percent_attr_strict(attrs, "l", "fillRect"),
    top: parse_percent_attr_strict(attrs, "t", "fillRect"),
    right: parse_percent_attr_strict(attrs, "r", "fillRect"),
    bottom: parse_percent_attr_strict(attrs, "b", "fillRect"),
  }
}

///|
/// Strict percentage attribute reader for src/fillRect: missing → 0%
/// (the spec default); present-but-malformed → `MalformedFill`.
fn parse_percent_attr_strict(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> @units.Percentage raise FillError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int_local(kv.1) {
        Some(n) => return @units.Percentage::from_ooxml(n)
        None =>
          raise MalformedFill(
            on + " attribute " + name + " is not an integer: " + kv.1,
          )
      }
    }
  }
  @units.Percentage(0.0)
}

///|
fn extract_blip_relationships(
  attrs : Array[(@xml.QName, String)],
) -> (String, String) {
  let mut embed = ""
  let mut link = ""
  for kv in attrs {
    if kv.0.uri == office_relationships_ns {
      if kv.0.local_name == "embed" {
        embed = kv.1
      } else if kv.0.local_name == "link" {
        link = kv.1
      }
    }
  }
  (embed, link)
}

// --- shared helpers ---

///|
/// Consume colour-choice children, returning the first one. Used by
/// `<a:fgClr>` / `<a:bgClr>` / `<a:gs>` whose bodies hold exactly one
/// colour element.
fn parse_first_color(
  r : @xml.XmlReader,
  context : String,
) -> Color raise FillError {
  let mut found : Color? = None
  while true {
    let ev = fill_next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == drawing_ns {
          let color = parse_color_element(r, child, child_attrs) catch {
            e => raise ColorFailure(context + ": " + e.to_string())
          }
          if found is None {
            found = Some(color)
          }
        } else {
          fill_skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match found {
    Some(c) => c
    None => raise MalformedFill(context + " has no colour child")
  }
}

///|
fn fill_next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise FillError {
  let event = r.next() catch {
    e => raise MalformedFill("xml error: " + e.to_string())
  }
  match event {
    Some(e) => e
    None => raise MalformedFill("unexpected end of input inside fill body")
  }
}

///|
fn fill_skip_subtree(r : @xml.XmlReader) -> Unit raise FillError {
  let mut depth = 1
  while depth > 0 {
    let ev = fill_next_event(r)
    match ev {
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => depth = depth - 1
      _ => ()
    }
  }
}

///|
fn fill_require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> String raise FillError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  raise MalformedFill(on + " is missing required attribute: " + name)
}

///|
fn optional_attr_local(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  ""
}

///|
fn parse_int_local(s : String) -> Int? {
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
fn parse_int64_local(s : String) -> Int64? {
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

///|
fn parse_bool_attr_opt(
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
fn[T] parse_enum_attr_opt(
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

///|
fn parse_emu_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int64_local(kv.1) {
        Some(n) => return Some(@units.Emu(n))
        None => return None
      }
    }
  }
  None
}

///|
fn parse_percent_attr_opt_fill(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int_local(kv.1) {
        Some(n) => return Some(@units.Percentage::from_ooxml(n))
        None => return None
      }
    }
  }
  None
}
