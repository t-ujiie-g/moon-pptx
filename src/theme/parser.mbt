// Theme XML reader.
//
// Consumes events from `xml::XmlReader` to build a `Theme`. The parser is
// strict on the parts it knows (`clrScheme`, `fontScheme`) and lenient on
// the rest: unmodelled elements (`fmtScheme`, `objectDefaults`, …) are
// silently skipped via `skip_subtree`. Lossless preservation of the skipped
// sections (ADR-004) will be added in a later phase.
//
// Recursive-descent contract: every `parse_*` function is called *just
// after* the corresponding StartElement has been consumed, and must consume
// events up to and including the matching EndElement.

///|
/// Parse a theme part from raw XML bytes.
pub fn Theme::parse(bytes : FixedArray[Byte]) -> Theme raise ThemeError {
  parse_theme_xml(bytes_to_string(bytes))
}

///|
/// Decode UTF-8 bytes to a `String`. We don't depend on `@fzip.str_from_u8`
/// here to keep the theme package free of the fzip dependency — the OPC
/// layer above us already gave us bytes and is responsible for fzip.
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise ThemeError {
  let chars : Array[Char] = []
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int().land(0xFF)
    if b0 < 0x80 {
      chars.push(b0.unsafe_to_char())
      i = i + 1
    } else if b0 < 0xC0 {
      raise MalformedTheme(
        "stray UTF-8 continuation byte at offset " + i.to_string(),
      )
    } else if b0 < 0xE0 {
      if i + 1 >= bytes.length() {
        raise MalformedTheme("truncated 2-byte UTF-8 sequence")
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let cp = (b0 - 0xC0) * 0x40 + (b1 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= bytes.length() {
        raise MalformedTheme("truncated 3-byte UTF-8 sequence")
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let b2 = bytes[i + 2].to_int().land(0xFF)
      let cp = (b0 - 0xE0) * 0x1000 + (b1 - 0x80) * 0x40 + (b2 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 3
    } else {
      if i + 3 >= bytes.length() {
        raise MalformedTheme("truncated 4-byte UTF-8 sequence")
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let b2 = bytes[i + 2].to_int().land(0xFF)
      let b3 = bytes[i + 3].to_int().land(0xFF)
      let cp = (b0 - 0xF0) * 0x40000 +
        (b1 - 0x80) * 0x1000 +
        (b2 - 0x80) * 0x40 +
        (b3 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 4
    }
  }
  String::from_array(chars)
}

///|
fn parse_theme_xml(xml : String) -> Theme raise ThemeError {
  let r = @xml.XmlReader::new(xml)
  // First event must be StartElement of <a:theme>.
  let theme_event = next_event(r)
  let theme_attrs = match theme_event {
    StartElement(name, attrs) => {
      expect_name(name, "theme")
      attrs
    }
    _ => raise MalformedTheme("expected <a:theme> root element")
  }
  let name = optional_attr(theme_attrs, "name")
  let mut color_scheme : ColorScheme? = None
  let mut font_scheme : FontScheme? = None
  // Walk children of <a:theme>.
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, _) => {
        if child.uri != drawing_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "themeElements" => {
            let (cs, fs) = parse_theme_elements(r)
            color_scheme = Some(cs)
            font_scheme = Some(fs)
          }
          _ => skip_subtree(r) // objectDefaults, extraClrSchemeLst, etc.
        }
      }
      EndElement(_) => break // </a:theme>
      _ => () // text/cdata between elements is ignorable here
    }
  }
  match (color_scheme, font_scheme) {
    (Some(cs), Some(fs)) => { name, color_scheme: cs, font_scheme: fs }
    (None, _) => raise MalformedTheme("theme is missing <a:clrScheme>")
    (_, None) => raise MalformedTheme("theme is missing <a:fontScheme>")
  }
}

///|
/// Parse the children of `<a:themeElements>`. Returns `(color_scheme, font_scheme)`.
fn parse_theme_elements(
  r : @xml.XmlReader,
) -> (ColorScheme, FontScheme) raise ThemeError {
  let mut cs : ColorScheme? = None
  let mut fs : FontScheme? = None
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) => {
        if child.uri != drawing_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "clrScheme" => cs = Some(parse_color_scheme(r, attrs))
          "fontScheme" => fs = Some(parse_font_scheme(r, attrs))
          _ => skip_subtree(r) // fmtScheme, etc.
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  match (cs, fs) {
    (Some(c), Some(f)) => (c, f)
    (None, _) => raise MalformedTheme("themeElements is missing clrScheme")
    (_, None) => raise MalformedTheme("themeElements is missing fontScheme")
  }
}

///|
/// Parse `<a:clrScheme>` children. Slots may appear in any order in real-
/// world themes, so we collect them into a map and assemble the struct at
/// the end.
fn parse_color_scheme(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> ColorScheme raise ThemeError {
  let name = optional_attr(attrs, "name")
  let slots : Map[String, ColorChoice] = Map::new()
  while true {
    let event = next_event(r)
    match event {
      StartElement(slot_name, _) => {
        if slot_name.uri != drawing_ns {
          skip_subtree(r)
          continue
        }
        let choice = parse_color_inside_wrapper(r, slot_name)
        slots[slot_name.local_name] = choice
      }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    name,
    dk1: require_slot(slots, "dk1"),
    lt1: require_slot(slots, "lt1"),
    dk2: require_slot(slots, "dk2"),
    lt2: require_slot(slots, "lt2"),
    accent1: require_slot(slots, "accent1"),
    accent2: require_slot(slots, "accent2"),
    accent3: require_slot(slots, "accent3"),
    accent4: require_slot(slots, "accent4"),
    accent5: require_slot(slots, "accent5"),
    accent6: require_slot(slots, "accent6"),
    hlink: require_slot(slots, "hlink"),
    fol_hlink: require_slot(slots, "folHlink"),
  }
}

///|
fn require_slot(
  slots : Map[String, ColorChoice],
  name : String,
) -> ColorChoice raise ThemeError {
  match slots.get(name) {
    Some(c) => c
    None => raise MalformedTheme("clrScheme missing slot: " + name)
  }
}

///|
/// Read the wrapper's single color child + the wrapper's EndElement.
fn parse_color_inside_wrapper(
  r : @xml.XmlReader,
  wrapper_name : @xml.QName,
) -> ColorChoice raise ThemeError {
  let mut found : ColorChoice? = None
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) => {
        if child.uri != drawing_ns {
          skip_subtree(r)
          continue
        }
        let choice = parse_color_choice(r, child, attrs)
        if found is None {
          found = Some(choice)
        }
        // ignore any further children — schema permits only one
      }
      EndElement(en) =>
        if en == wrapper_name {
          break
        } else {
          // shouldn't happen with well-formed XML — reader catches mismatches
          ()
        }
      _ => ()
    }
  }
  match found {
    Some(c) => c
    None =>
      raise MalformedTheme(
        "color slot " + wrapper_name.local_name + " has no color child",
      )
  }
}

///|
/// Parse a single color element. Currently handles `srgbClr` and `sysClr`
/// (covers all real-world theme color schemes); other variants raise
/// `MalformedTheme` so we notice and add support intentionally.
fn parse_color_choice(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> ColorChoice raise ThemeError {
  match name.local_name {
    "srgbClr" => {
      let hex = require_attr(attrs, "val")
      let rgb = @units.RgbColor::parse_hex(hex) catch {
        _ =>
          raise MalformedTheme("srgbClr val is not a 6-hex-digit color: " + hex)
      }
      skip_subtree(r) // consume any color modifier children + EndElement
      Srgb(rgb)
    }
    "sysClr" => {
      let val = require_attr(attrs, "val")
      let last = optional_attr(attrs, "lastClr")
      let last_clr = if last.length() > 0 {
        let parsed = @units.RgbColor::parse_hex(last) catch {
          _ =>
            raise MalformedTheme(
              "sysClr lastClr is not a 6-hex-digit color: " + last,
            )
        }
        Some(parsed)
      } else {
        None
      }
      skip_subtree(r)
      Sys({ val, last_clr })
    }
    other =>
      raise MalformedTheme("unsupported color element in clrScheme: " + other)
  }
}

///|
/// Parse `<a:fontScheme>` children.
fn parse_font_scheme(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> FontScheme raise ThemeError {
  let name = optional_attr(attrs, "name")
  let mut major : FontCollection? = None
  let mut minor : FontCollection? = None
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, _) => {
        if child.uri != drawing_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "majorFont" => major = Some(parse_font_collection(r, child))
          "minorFont" => minor = Some(parse_font_collection(r, child))
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  match (major, minor) {
    (Some(mj), Some(mn)) => { name, major_font: mj, minor_font: mn }
    (None, _) => raise MalformedTheme("fontScheme missing majorFont")
    (_, None) => raise MalformedTheme("fontScheme missing minorFont")
  }
}

///|
fn parse_font_collection(
  r : @xml.XmlReader,
  wrapper_name : @xml.QName,
) -> FontCollection raise ThemeError {
  let mut latin = ""
  let mut ea = ""
  let mut cs = ""
  let scripts : Array[ScriptFont] = []
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) => {
        if child.uri != drawing_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "latin" => {
            latin = require_attr(attrs, "typeface")
            skip_subtree(r)
          }
          "ea" => {
            ea = optional_attr(attrs, "typeface")
            skip_subtree(r)
          }
          "cs" => {
            cs = optional_attr(attrs, "typeface")
            skip_subtree(r)
          }
          "font" => {
            let script = require_attr(attrs, "script")
            let typeface = require_attr(attrs, "typeface")
            scripts.push({ script, typeface })
            skip_subtree(r)
          }
          _ => skip_subtree(r)
        }
      }
      EndElement(en) => if en == wrapper_name { break }
      _ => ()
    }
  }
  { latin, ea, cs, scripts }
}

// --- shared event helpers ---

///|
/// Consume events until the EndElement that closes the most-recent
/// StartElement is seen. Caller must invoke this when a StartElement has
/// just been consumed (so depth is 1 deeper than the surrounding scope).
fn skip_subtree(r : @xml.XmlReader) -> Unit raise ThemeError {
  let mut depth = 1
  while depth > 0 {
    let event = next_event(r)
    match event {
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => depth = depth - 1
      _ => ()
    }
  }
}

///|
/// Read the next event, mapping reader errors and EOF to `ThemeError`.
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise ThemeError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise MalformedTheme("unexpected end of input")
  }
}

///|
fn expect_name(name : @xml.QName, expected : String) -> Unit raise ThemeError {
  if name.uri != drawing_ns || name.local_name != expected {
    raise MalformedTheme(
      "expected element <a:" + expected + "> but got <" + name.local_name + ">",
    )
  }
}

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  attr_name : String,
) -> String raise ThemeError {
  for kv in attrs {
    if kv.0.local_name == attr_name {
      return kv.1
    }
  }
  raise MalformedTheme("missing required attribute: " + attr_name)
}

///|
fn optional_attr(
  attrs : Array[(@xml.QName, String)],
  attr_name : String,
) -> String {
  for kv in attrs {
    if kv.0.local_name == attr_name {
      return kv.1
    }
  }
  ""
}
