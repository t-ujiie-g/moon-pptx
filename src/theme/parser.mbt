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
/// Decode UTF-8 bytes via the shared `@oxml.bytes_to_string` helper,
/// mapping any `Utf8Error` into the domain error variant.
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise ThemeError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise MalformedTheme(e.to_string())
  }
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
  let extension : Array[@xml.XmlElement] = []
  // Walk children of <a:theme>.
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "themeElements" => {
              let (cs, fs) = parse_theme_elements(r, extension)
              color_scheme = Some(cs)
              font_scheme = Some(fs)
            }
            // objectDefaults, extraClrSchemeLst, custClrLst, extLst, …
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break // </a:theme>
      _ => () // text/cdata between elements is ignorable here
    }
  }
  match (color_scheme, font_scheme) {
    (Some(cs), Some(fs)) =>
      { name, color_scheme: cs, font_scheme: fs, extension }
    (None, _) => raise MalformedTheme("theme is missing <a:clrScheme>")
    (_, None) => raise MalformedTheme("theme is missing <a:fontScheme>")
  }
}

///|
/// Parse the children of `<a:themeElements>`. Returns `(color_scheme,
/// font_scheme)`. Unmodelled `<a:themeElements>` children
/// (`<a:fmtScheme>`, `<a:objectDefaults>`, …) are folded into the
/// theme-level `extension` array supplied by the caller — they
/// structurally belong to a different parent, but `name.local_name`
/// tells writers where to re-emit them.
fn parse_theme_elements(
  r : @xml.XmlReader,
  theme_extension : Array[@xml.XmlElement],
) -> (ColorScheme, FontScheme) raise ThemeError {
  let mut cs : ColorScheme? = None
  let mut fs : FontScheme? = None
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          theme_extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "clrScheme" => cs = Some(parse_color_scheme(r, attrs))
            "fontScheme" => fs = Some(parse_font_scheme(r, attrs))
            // fmtScheme, objectDefaults, …
            _ => theme_extension.push(collect_subtree_unknown(r, child, attrs))
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
  let slots : Map[String, @oxml.Color] = Map([])
  let extension : Array[@xml.XmlElement] = []
  while true {
    let event = next_event(r)
    match event {
      StartElement(slot_name, slot_attrs) =>
        if slot_name.uri != @oxml.drawing_ns {
          extension.push(collect_subtree_unknown(r, slot_name, slot_attrs))
        } else {
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
    extension,
  }
}

///|
fn require_slot(
  slots : Map[String, @oxml.Color],
  name : String,
) -> @oxml.Color raise ThemeError {
  match slots.get(name) {
    Some(c) => c
    None => raise MalformedTheme("clrScheme missing slot: " + name)
  }
}

///|
/// Read the wrapper's single colour child + the wrapper's EndElement.
/// Delegates colour parsing to `@oxml.parse_color_element` so theme
/// slots, run-level fills, and (eventually) gradient stops all share
/// one parse path.
fn parse_color_inside_wrapper(
  r : @xml.XmlReader,
  wrapper_name : @xml.QName,
) -> @oxml.Color raise ThemeError {
  let mut found : @oxml.Color? = None
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) => {
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
          continue
        }
        let color = @oxml.parse_color_element(r, child, attrs) catch {
          e =>
            raise MalformedTheme(
              "color slot " + wrapper_name.local_name + ": " + e.to_string(),
            )
        }
        if found is None {
          found = Some(color)
        }
        // ignore any further children — schema permits only one
      }
      EndElement(en) => if en == wrapper_name { break } else { () }
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
/// Parse `<a:fontScheme>` children.
fn parse_font_scheme(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> FontScheme raise ThemeError {
  let name = optional_attr(attrs, "name")
  let mut major : FontCollection? = None
  let mut minor : FontCollection? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "majorFont" => major = Some(parse_font_collection(r, child))
            "minorFont" => minor = Some(parse_font_collection(r, child))
            _ => extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match (major, minor) {
    (Some(mj), Some(mn)) => { name, major_font: mj, minor_font: mn, extension }
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
  let extension : Array[@xml.XmlElement] = []
  while true {
    let event = next_event(r)
    match event {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
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
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(en) => if en == wrapper_name { break }
      _ => ()
    }
  }
  { latin, ea, cs, scripts, extension }
}

// --- shared event helpers ---

///|
/// Consume events until the EndElement that closes the most-recent
/// StartElement is seen. Stays domain-local so it inherits `next_event`'s
/// `XmlFailure` / `MalformedTheme` distinction.
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
/// Read the next event, mapping reader errors to `XmlFailure` and EOF
/// to `MalformedTheme`. Kept domain-local (rather than delegating to
/// `@oxml.next_event`) so the underlying `@xml.XmlError` variant can be
/// preserved in `ThemeError::XmlFailure(kind, msg)` — the shared
/// `XmlReadError` flattens both error kinds to a string.
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise ThemeError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise MalformedTheme("unexpected end of input")
  }
}

///|
fn expect_name(name : @xml.QName, expected : String) -> Unit raise ThemeError {
  if name.uri != @oxml.drawing_ns || name.local_name != expected {
    raise MalformedTheme(
      "expected element <a:" + expected + "> but got <" + name.local_name + ">",
    )
  }
}

///|
/// Thin delegator to `@oxml.require_attr`. The theme parser uses a 2-arg
/// signature historically (no enclosing-element context), so we pass the
/// attribute name itself as the context — the resulting error message
/// remains readable.
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  attr_name : String,
) -> String raise ThemeError {
  @oxml.require_attr(attrs, attr_name, attr_name) catch {
    e => raise MalformedTheme(e.to_string())
  }
}

///|
fn optional_attr(
  attrs : Array[(@xml.QName, String)],
  attr_name : String,
) -> String {
  @oxml.optional_attr_or(attrs, attr_name, "")
}

///|
/// Thin wrapper around `@oxml.collect_subtree` that translates the neutral
/// `XmlReadError` into `ThemeError::MalformedTheme`. Centralises the
/// conversion so the unknown-element capture sites in the theme parser
/// stay one-liners.
fn collect_subtree_unknown(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> @xml.XmlElement raise ThemeError {
  @oxml.collect_subtree(r, name, attrs) catch {
    e => raise MalformedTheme(e.to_string())
  }
}
