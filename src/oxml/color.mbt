// Unified DrawingML color model.
//
// Every OOXML "color choice" — the `EG_ColorChoice` group in ECMA-376
// §20.1.10.7 — is one of six concrete colour elements (`<a:srgbClr>`,
// `<a:hslClr>`, `<a:sysClr>`, `<a:schemeClr>`, `<a:prstClr>`,
// `<a:scrgbClr>`) optionally followed by any number of *colour
// modifier* children (`<a:tint>`, `<a:shade>`, `<a:satMod>`,
// `<a:lumMod>`, `<a:alpha>`, …). The same group appears verbatim in
// every solid-fill / gradient-stop / line-fill / theme-slot context.
//
// Before this slice we modelled colours three different ways:
//   * `@theme.ColorChoice` — Srgb + Sys (theme color scheme slots).
//   * `@slide.RunFill` — SolidRgb + SolidTheme (run-level solid fill).
//   * `@units.SchemeColor` — typed scheme reference with modifiers
//     (high-level builder API; not exercised by parsers yet).
//
// Phase 3e1 consolidates the parser-side representation into one
// `Color { base, transforms }` so shape fill, run fill, theme slots,
// gradient stops, and line fills all share one parser path. The high-
// level `@units.SchemeColor` builder API stays as-is for now — it's a
// user-facing convenience, distinct from the OOXML wire-format model
// owned by this file.

///|
/// `<a:sysClr val="windowText" lastClr="000000"/>` — a host system
/// colour with a fallback RGB used when the system value can't be
/// resolved. The string `val` is the spec's `ST_SystemColorVal`; we
/// keep it raw so unrecognised system values round-trip.
pub(all) struct SysColor {
  val : String
  last_clr : @units.RgbColor?
} derive(Eq, Debug)

///|
pub impl Show for SysColor with output(self, logger) {
  logger.write_string("SysColor(")
  logger.write_object(self.val)
  match self.last_clr {
    Some(c) => {
      logger.write_string(", last=")
      logger.write_object(c)
    }
    None => ()
  }
  logger.write_string(")")
}

///|
/// One of the six DrawingML colour element kinds. Carries the raw value
/// off the element's start tag; modifiers attach via the enclosing
/// `Color` wrapper.
pub(all) enum ColorBase {
  /// `<a:srgbClr val="FF0000"/>` — literal 24-bit RGB.
  Srgb(@units.RgbColor)
  /// `<a:hslClr hue="..." sat="..." lum="..."/>` — hue/saturation/lightness.
  Hsl(@units.HslColor)
  /// `<a:sysClr val="..." lastClr="..."/>`.
  Sys(SysColor)
  /// `<a:schemeClr val="..."/>` — reference to a theme color slot.
  Scheme(@units.ThemeColor)
  /// `<a:prstClr val="..."/>` — named preset colour (e.g. `"red"`,
  /// `"slateGray"`). We keep the string because the preset palette is
  /// large and rarely the deciding factor in fidelity.
  Preset(String)
  /// `<a:scrgbClr r="..." g="..." b="..."/>` — percentage RGB.
  Scrgb(@units.Percentage, @units.Percentage, @units.Percentage)
} derive(Eq, Debug)

///|
pub impl Show for ColorBase with output(self, logger) {
  match self {
    Srgb(c) => {
      logger.write_string("Srgb(")
      logger.write_object(c)
      logger.write_string(")")
    }
    Hsl(c) => {
      logger.write_string("Hsl(")
      logger.write_object(c)
      logger.write_string(")")
    }
    Sys(c) => {
      logger.write_string("Sys(")
      logger.write_object(c)
      logger.write_string(")")
    }
    Scheme(c) => {
      logger.write_string("Scheme(")
      logger.write_object(c)
      logger.write_string(")")
    }
    Preset(s) => {
      logger.write_string("Preset(")
      logger.write_object(s)
      logger.write_string(")")
    }
    Scrgb(r, g, b) => {
      logger.write_string("Scrgb(")
      logger.write_object(r)
      logger.write_string(", ")
      logger.write_object(g)
      logger.write_string(", ")
      logger.write_object(b)
      logger.write_string(")")
    }
  }
}

///|
/// A parsed DrawingML colour: one of the six base kinds plus an
/// ordered list of modifier transforms.
///
/// Modifier order matters per spec — applying `Tint(50%)` then
/// `Shade(50%)` is not the same as the reverse — so we preserve source
/// order via `Array[ColorTransform]`. The supported transforms today
/// match `@units.ColorTransform` (Tint / Shade / SatMod / LumMod /
/// Alpha); long-tail modifiers (hueMod, redMod, comp, inv, gamma,
/// gray, …) are accepted by the parser but currently dropped — widen
/// `@units.ColorTransform` when a real PPTX exposes them.
pub(all) struct Color {
  base : ColorBase
  transforms : Array[@units.ColorTransform]
} derive(Eq, Debug)

///|
pub impl Show for Color with output(self, logger) {
  logger.write_string("Color(")
  logger.write_object(self.base)
  if self.transforms.length() > 0 {
    logger.write_string(", [")
    for i, t in self.transforms {
      if i > 0 {
        logger.write_string(", ")
      }
      logger.write_object(t)
    }
    logger.write_string("]")
  }
  logger.write_string(")")
}

///|
/// Construct a colour with no modifiers.
pub fn Color::of(base : ColorBase) -> Color {
  { base, transforms: [] }
}

///|
/// Convenience: literal RGB colour with no modifiers.
pub fn Color::srgb(rgb : @units.RgbColor) -> Color {
  Color::of(Srgb(rgb))
}

///|
/// Convenience: theme-scheme reference with no modifiers.
pub fn Color::scheme(slot : @units.ThemeColor) -> Color {
  Color::of(Scheme(slot))
}

// --- parser ---

///|
/// Errors raised by `parse_color_element`.
pub(all) suberror ColorError {
  /// The element is not one of the six known colour-element local names.
  UnknownColorElement(String)
  /// A required attribute (`val`, `hue`/`sat`/`lum`, `r`/`g`/`b`) is
  /// missing or unparseable. Payload is a human-readable description.
  MalformedColor(String)
} derive(Eq, Debug)

///|
pub impl Show for ColorError with output(self, logger) {
  match self {
    UnknownColorElement(s) => {
      logger.write_string("UnknownColorElement(")
      logger.write_object(s)
      logger.write_string(")")
    }
    MalformedColor(s) => {
      logger.write_string("MalformedColor(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}

///|
/// Parse one colour-element start tag (e.g. `<a:srgbClr val="FF0000"`)
/// plus its body into a `Color`. `name` is the QName from the consumed
/// StartElement, `attrs` are the attributes of that element, and `r`
/// is positioned just after the StartElement — this function consumes
/// every event up to and including the matching EndElement.
///
/// Returns `Err(UnknownColorElement)` for an element whose local name
/// is not one of `srgbClr` / `hslClr` / `sysClr` / `schemeClr` /
/// `prstClr` / `scrgbClr`. Returns `Err(MalformedColor)` for missing
/// or malformed required attributes.
pub fn parse_color_element(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> Color raise ColorError {
  let base : ColorBase = match name.local_name {
    "srgbClr" => {
      let hex = require_attr(attrs, "val", "srgbClr")
      let rgb = @units.RgbColor::parse_hex(hex) catch {
        _ =>
          raise MalformedColor("srgbClr val is not a 6-hex-digit color: " + hex)
      }
      Srgb(rgb)
    }
    "hslClr" => {
      let hue = parse_angle_required(attrs, "hue", "hslClr")
      let sat = parse_percent_required(attrs, "sat", "hslClr")
      let lum = parse_percent_required(attrs, "lum", "hslClr")
      Hsl(@units.HslColor::new(hue, sat, lum))
    }
    "sysClr" => {
      let val = require_attr(attrs, "val", "sysClr")
      let last = optional_attr(attrs, "lastClr")
      let last_clr = if last.length() > 0 {
        let parsed = @units.RgbColor::parse_hex(last) catch {
          _ =>
            raise MalformedColor(
              "sysClr lastClr is not a 6-hex-digit color: " + last,
            )
        }
        Some(parsed)
      } else {
        None
      }
      Sys({ val, last_clr })
    }
    "schemeClr" => {
      let raw = require_attr(attrs, "val", "schemeClr")
      let theme = @units.ThemeColor::from_xml(raw) catch {
        _ =>
          raise MalformedColor(
            "schemeClr val is not a ST_SchemeColorVal: " + raw,
          )
      }
      Scheme(theme)
    }
    "prstClr" => Preset(require_attr(attrs, "val", "prstClr"))
    "scrgbClr" => {
      let red = parse_percent_required(attrs, "r", "scrgbClr")
      let green = parse_percent_required(attrs, "g", "scrgbClr")
      let blue = parse_percent_required(attrs, "b", "scrgbClr")
      Scrgb(red, green, blue)
    }
    _ => raise UnknownColorElement(name.local_name)
  }
  // Walk the body looking for colour-modifier children.
  let transforms : Array[@units.ColorTransform] = []
  while true {
    let event = r.next() catch {
      e =>
        raise MalformedColor("xml error inside colour body: " + e.to_string())
    }
    match event {
      Some(StartElement(child, child_attrs)) => {
        if child.uri == name.uri {
          match transform_from(child.local_name, child_attrs) {
            Some(t) => transforms.push(t)
            None => () // unsupported transform — silently drop for now
          }
        }
        skip_subtree(r)
      }
      Some(EndElement(_)) => break
      Some(Text(_)) | Some(CData(_)) => ()
      None => raise MalformedColor("unexpected end of input inside colour body")
    }
  }
  { base, transforms }
}

///|
/// Map a colour-modifier element name + attributes to a typed
/// `ColorTransform`. Returns `None` for the long-tail modifiers
/// (`hueMod`, `redMod`, etc.) that the model currently drops.
fn transform_from(
  local_name : String,
  attrs : Array[(@xml.QName, String)],
) -> @units.ColorTransform? {
  match local_name {
    "tint" => parse_percent_attr_opt(attrs, "val").map(fn(p) { Tint(p) })
    "shade" => parse_percent_attr_opt(attrs, "val").map(fn(p) { Shade(p) })
    "satMod" => parse_percent_attr_opt(attrs, "val").map(fn(p) { SatMod(p) })
    "lumMod" => parse_percent_attr_opt(attrs, "val").map(fn(p) { LumMod(p) })
    "alpha" => parse_percent_attr_opt(attrs, "val").map(fn(p) { Alpha(p) })
    _ => None
  }
}

///|
/// Skip events until the closing tag for the element whose StartElement
/// was just consumed. Local copy of the helper used by domain parsers.
fn skip_subtree(r : @xml.XmlReader) -> Unit raise ColorError {
  let mut depth = 1
  while depth > 0 {
    let event = r.next() catch {
      e =>
        raise MalformedColor(
          "xml error inside skipped subtree: " + e.to_string(),
        )
    }
    match event {
      Some(StartElement(_, _)) => depth = depth + 1
      Some(EndElement(_)) => depth = depth - 1
      Some(_) => ()
      None =>
        raise MalformedColor("unexpected end of input inside skipped subtree")
    }
  }
}

// --- attribute helpers ---

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> String raise ColorError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  raise MalformedColor(on + " is missing required attribute: " + name)
}

///|
fn optional_attr(attrs : Array[(@xml.QName, String)], name : String) -> String {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  ""
}

///|
fn parse_angle_required(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> Double raise ColorError {
  let raw = require_attr(attrs, name, on)
  match parse_int(raw) {
    Some(n) => n.to_double() / 60_000.0
    None => raise MalformedColor(on + " " + name + " is not an integer: " + raw)
  }
}

///|
fn parse_percent_required(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> Double raise ColorError {
  let raw = require_attr(attrs, name, on)
  match parse_int(raw) {
    Some(n) => n.to_double() / 1000.0
    None => raise MalformedColor(on + " " + name + " is not an integer: " + raw)
  }
}

///|
fn parse_percent_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int(kv.1) {
        Some(n) => return Some(@units.Percentage::from_ooxml(n))
        None => return None
      }
    }
  }
  None
}

///|
fn parse_int(s : String) -> Int? {
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
/// Percentage parser for `<a:scrgbClr>` / `<a:hslClr>`. Same as above
/// but yields a typed `Percentage`. Used by tests; production parser
/// uses the local helpers above.
pub fn parse_percent_value(raw : String) -> @units.Percentage? {
  match parse_int(raw) {
    Some(n) => Some(@units.Percentage::from_ooxml(n))
    None => None
  }
}
