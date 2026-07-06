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
// `Color { base, transforms }` is the single parser-side
// representation — shape fill, run fill, theme slots, gradient stops,
// and line fills all share one parser path. The high-level
// `@units.SchemeColor` builder API stays distinct — it's a user-facing
// convenience, separate from the OOXML wire-format model owned here.

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
pub impl Show for SysColor with fn output(self, logger) {
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
pub impl Show for ColorBase with fn output(self, logger) {
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
  /// Lossless preservation (ADR-004): colour-modifier children that the
  /// model does not yet type — `hueMod`, `redMod`, `greenMod`, `blueMod`,
  /// `comp`, `inv`, `gamma`, `gray`, … — and any foreign-namespace
  /// children. Modeled modifiers (`tint`, `shade`, `satMod`, `lumMod`,
  /// `alpha`) live in `transforms` and do NOT duplicate here.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Color with fn output(self, logger) {
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
  { base, transforms: [], extension: [] }
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

// --- writer ---

///|
/// Emit a `Color` onto `w` as the DrawingML colour element matching
/// its base kind (`<a:srgbClr>` / `<a:hslClr>` / `<a:sysClr>` /
/// `<a:schemeClr>` / `<a:prstClr>` / `<a:scrgbClr>`). Modifier
/// children come from `transforms` (modeled) and `extension`
/// (unmodelled — replayed verbatim via `write_xml_element`).
///
/// Caller must have already bound the drawing-ml namespace (e.g. via
/// `WriteCtx::with_well_known_prefixes` + `bind_namespace("a", …)`).
pub fn write_color(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  c : Color,
) -> Unit raise @xml.XmlError {
  let name = match c.base {
    Srgb(_) => "srgbClr"
    Hsl(_) => "hslClr"
    Sys(_) => "sysClr"
    Scheme(_) => "schemeClr"
    Preset(_) => "prstClr"
    Scrgb(_, _, _) => "scrgbClr"
  }
  w.start_element(@xml.QName::new(drawing_ns, name))
  match c.base {
    Srgb(rgb) => w.attribute(@xml.QName::unqualified("val"), rgb.to_hex())
    Hsl(hsl) => {
      let hue_ooxml = @units.Angle(hsl.hue).to_ooxml()
      let sat_ooxml = @units.Percentage(hsl.saturation).to_ooxml()
      let lum_ooxml = @units.Percentage(hsl.lightness).to_ooxml()
      w.attribute(@xml.QName::unqualified("hue"), hue_ooxml.to_string())
      w.attribute(@xml.QName::unqualified("sat"), sat_ooxml.to_string())
      w.attribute(@xml.QName::unqualified("lum"), lum_ooxml.to_string())
    }
    Sys(sys) => {
      w.attribute(@xml.QName::unqualified("val"), sys.val)
      match sys.last_clr {
        Some(rgb) =>
          w.attribute(@xml.QName::unqualified("lastClr"), rgb.to_hex())
        None => ()
      }
    }
    Scheme(slot) => w.attribute(@xml.QName::unqualified("val"), slot.to_xml())
    Preset(s) => w.attribute(@xml.QName::unqualified("val"), s)
    Scrgb(r, g, b) => {
      w.attribute(@xml.QName::unqualified("r"), r.to_ooxml().to_string())
      w.attribute(@xml.QName::unqualified("g"), g.to_ooxml().to_string())
      w.attribute(@xml.QName::unqualified("b"), b.to_ooxml().to_string())
    }
  }
  // Modeled modifiers — emit in the recorded order.
  for t in c.transforms {
    write_color_transform(w, t)
  }
  // Unmodelled modifier tail (hueMod, redMod, comp, inv, gamma, gray,
  // and any foreign-namespace children) — replay verbatim.
  for ext in c.extension {
    write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit one modeled colour transform child (`<a:tint>` / `<a:shade>` /
/// `<a:satMod>` / `<a:lumMod>` / `<a:alpha>`). All five take a single
/// `val="..."` attribute in 1/1000-percent units.
fn write_color_transform(
  w : @xml.XmlWriter,
  t : @units.ColorTransform,
) -> Unit raise @xml.XmlError {
  let (local_name, pct) = match t {
    Tint(p) => ("tint", p)
    Shade(p) => ("shade", p)
    SatMod(p) => ("satMod", p)
    LumMod(p) => ("lumMod", p)
    Alpha(p) => ("alpha", p)
  }
  w.start_element(@xml.QName::new(drawing_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), pct.to_ooxml().to_string())
  w.end_element()
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
pub impl Show for ColorError with fn output(self, logger) {
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
      let hex = require_attr(attrs, "val", "srgbClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      let rgb = @units.RgbColor::parse_hex(hex) catch {
        _ =>
          raise MalformedColor("srgbClr val is not a 6-hex-digit color: " + hex)
      }
      Srgb(rgb)
    }
    "hslClr" => {
      let hue = (require_angle(attrs, "hue", "hslClr") catch {
        e => raise MalformedColor(e.to_string())
      }).degrees()
      let sat = (require_pct(attrs, "sat", "hslClr") catch {
        e => raise MalformedColor(e.to_string())
      }).value()
      let lum = (require_pct(attrs, "lum", "hslClr") catch {
        e => raise MalformedColor(e.to_string())
      }).value()
      Hsl(@units.HslColor::new(hue, sat, lum))
    }
    "sysClr" => {
      let val = require_attr(attrs, "val", "sysClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      let last_clr = match optional_attr(attrs, "lastClr") {
        Some(s) => {
          let parsed = @units.RgbColor::parse_hex(s) catch {
            _ =>
              raise MalformedColor(
                "sysClr lastClr is not a 6-hex-digit color: " + s,
              )
          }
          Some(parsed)
        }
        None => None
      }
      Sys({ val, last_clr })
    }
    "schemeClr" => {
      let raw = require_attr(attrs, "val", "schemeClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      let theme = @units.ThemeColor::from_xml(raw) catch {
        _ =>
          raise MalformedColor(
            "schemeClr val is not a ST_SchemeColorVal: " + raw,
          )
      }
      Scheme(theme)
    }
    "prstClr" => {
      let v = require_attr(attrs, "val", "prstClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      Preset(v)
    }
    "scrgbClr" => {
      let red = require_pct(attrs, "r", "scrgbClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      let green = require_pct(attrs, "g", "scrgbClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      let blue = require_pct(attrs, "b", "scrgbClr") catch {
        e => raise MalformedColor(e.to_string())
      }
      Scrgb(red, green, blue)
    }
    _ => raise UnknownColorElement(name.local_name)
  }
  // Walk the body looking for colour-modifier children. Modeled
  // modifiers (tint / shade / satMod / lumMod / alpha) fold into
  // `transforms`; everything else (hueMod / redMod / comp / inv /
  // gamma / gray / foreign-namespace) lands on `extension` per ADR-004
  // so it round-trips.
  let transforms : Array[@units.ColorTransform] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let event = r.next() catch {
      e =>
        raise MalformedColor("xml error inside colour body: " + e.to_string())
    }
    match event {
      Some(StartElement(child, child_attrs)) => {
        let modeled = if child.uri == name.uri {
          match transform_from(child.local_name, child_attrs) {
            Some(t) => {
              transforms.push(t)
              true
            }
            None => false
          }
        } else {
          false
        }
        if modeled {
          skip_subtree(r) catch {
            e => raise MalformedColor(e.to_string())
          }
        } else {
          let captured = collect_subtree(r, child, child_attrs) catch {
            e => raise MalformedColor(e.to_string())
          }
          extension.push(captured)
        }
      }
      Some(EndElement(_)) => break
      Some(Text(_)) | Some(CData(_)) => ()
      None => raise MalformedColor("unexpected end of input inside colour body")
    }
  }
  { base, transforms, extension }
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
    "tint" => pct_attr_opt(attrs, "val").map(fn(p) { Tint(p) })
    "shade" => pct_attr_opt(attrs, "val").map(fn(p) { Shade(p) })
    "satMod" => pct_attr_opt(attrs, "val").map(fn(p) { SatMod(p) })
    "lumMod" => pct_attr_opt(attrs, "val").map(fn(p) { LumMod(p) })
    "alpha" => pct_attr_opt(attrs, "val").map(fn(p) { Alpha(p) })
    _ => None
  }
}
