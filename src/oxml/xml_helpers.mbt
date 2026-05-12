// Shared XML / attribute helpers for OOXML parsers.
//
// Before this module existed, every typed parser (`@theme`, `@slide_master`,
// `@slide`, plus `@oxml.color` / `fill` / `stroke` / `effect`) had its own
// copy of `next_event` / `skip_subtree` / `require_attr` / `*_attr_opt`
// because each wanted to raise its own domain suberror — `MalformedTheme` /
// `MalformedFill` / `MalformedEffect` / … On its own the duplication is
// trivial (~15 lines per file) but it adds up to ~300 lines across the
// seven parsers, and every new parser slice has to copy the pattern again.
//
// This module owns one copy. The two categories:
//
// - **Option-returning helpers** (`optional_attr`, `emu_attr_opt`,
//   `pct_attr_opt`, `angle_attr_opt`, `bool_attr_opt`, `enum_attr_opt`)
//   take no error type — they just return `None` on absent / unparseable
//   input.  Callers use them directly: `let w = @oxml.emu_attr_opt(attrs, "w")`.
//
// - **Raising helpers** (`next_event`, `skip_subtree`, `require_attr`,
//   `require_emu`, `require_angle`, `require_pct`) raise the neutral
//   `XmlReadError`. Callers catch and re-raise as their own domain
//   suberror:
//
//   ```
//   let val = @oxml.require_emu(attrs, "x", "off") catch {
//     e => raise Malformed(e.to_string())
//   }
//   ```

///|
/// Neutral error type raised by the shared XML read helpers.  Callers
/// translate it into their own domain suberror at the use site.
pub(all) suberror XmlReadError {
  XmlReadError(String)
} derive(Eq, Debug)

///|
pub impl Show for XmlReadError with output(self, logger) {
  let XmlReadError(s) = self
  logger.write_string("XmlReadError(")
  logger.write_object(s)
  logger.write_string(")")
}

// --- event helpers ---

///|
/// Pull the next event from `r`, treating end-of-input as an error.
/// Returns the raw `XmlEvent` so callers can pattern-match.
pub fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise XmlReadError {
  let event = r.next() catch {
    e => raise XmlReadError("xml error: " + e.to_string())
  }
  match event {
    Some(e) => e
    None => raise XmlReadError("unexpected end of input")
  }
}

///|
/// Consume events until the matching EndElement for the StartElement just
/// consumed. Depth-tracking handles nested children.
pub fn skip_subtree(r : @xml.XmlReader) -> Unit raise XmlReadError {
  let mut depth = 1
  while depth > 0 {
    let ev = next_event(r)
    match ev {
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => depth = depth - 1
      _ => ()
    }
  }
}

// --- attribute lookups (no error type) ---

///|
/// Return the value of the unprefixed attribute named `name`, or `None`
/// if absent. OOXML attributes are almost always unprefixed (the prefixed
/// ones — `r:id`, `xml:space`, `xmlns:*` — have their own lookup paths).
pub fn optional_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return Some(kv.1)
    }
  }
  None
}

///|
/// Like `optional_attr` but lets the caller pick a default for the absent
/// case. Useful when "" is a valid default and the caller doesn't want to
/// match on `Option`.
pub fn optional_attr_or(
  attrs : Array[(@xml.QName, String)],
  name : String,
  default : String,
) -> String {
  match optional_attr(attrs, name) {
    Some(v) => v
    None => default
  }
}

///|
/// EMU attribute lookup. Absent or unparseable → `None`.
pub fn emu_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu? {
  match optional_attr(attrs, name) {
    Some(raw) =>
      match parse_signed_int64(raw) {
        Some(n) => Some(@units.Emu(n))
        None => None
      }
    None => None
  }
}

///|
/// Percentage attribute lookup (OOXML 1/1000-percent units).
pub fn pct_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage? {
  match optional_attr(attrs, name) {
    Some(raw) =>
      match parse_signed_int(raw) {
        Some(n) => Some(@units.Percentage::from_ooxml(n))
        None => None
      }
    None => None
  }
}

///|
/// Angle attribute lookup (OOXML 1/60_000-degree units).
pub fn angle_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Angle? {
  match optional_attr(attrs, name) {
    Some(raw) =>
      match parse_signed_int(raw) {
        Some(n) => Some(@units.Angle::from_ooxml(n))
        None => None
      }
    None => None
  }
}

///|
/// Boolean attribute lookup. OOXML accepts `1` / `0` / `true` / `false`.
/// Any other value (including absent) returns `None` — callers treat
/// `None` as "inherit from defaults".
pub fn bool_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Bool? {
  match optional_attr(attrs, name) {
    Some("1") | Some("true") => Some(true)
    Some("0") | Some("false") => Some(false)
    _ => None
  }
}

///|
/// Enum attribute lookup via a caller-supplied `from_xml` parser.
/// Unknown values map to `None`.
pub fn[T] enum_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
  from_xml : (String) -> T?,
) -> T? {
  match optional_attr(attrs, name) {
    Some(raw) => from_xml(raw)
    None => None
  }
}

// --- raising helpers ---

///|
/// Look up the unprefixed attribute `name`; raise if absent.  `on` names
/// the enclosing element (or context) so the error message can pinpoint
/// the violation: `MalformedFill("<a:srgbClr> is missing required attribute: val")`.
pub fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> String raise XmlReadError {
  match optional_attr(attrs, name) {
    Some(v) => v
    None => raise XmlReadError(on + " is missing required attribute: " + name)
  }
}

///|
/// Required EMU attribute. Raises if absent or unparseable.
pub fn require_emu(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> @units.Emu raise XmlReadError {
  let raw = require_attr(attrs, name, on)
  match parse_signed_int64(raw) {
    Some(n) => @units.Emu(n)
    None =>
      raise XmlReadError(
        on + " attribute " + name + " is not an integer: " + raw,
      )
  }
}

///|
/// Required Angle attribute (1/60_000 degree).
pub fn require_angle(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> @units.Angle raise XmlReadError {
  let raw = require_attr(attrs, name, on)
  match parse_signed_int(raw) {
    Some(n) => @units.Angle::from_ooxml(n)
    None =>
      raise XmlReadError(
        on + " attribute " + name + " is not an integer: " + raw,
      )
  }
}

///|
/// Required Percentage attribute (1/1000 percent).
pub fn require_pct(
  attrs : Array[(@xml.QName, String)],
  name : String,
  on : String,
) -> @units.Percentage raise XmlReadError {
  let raw = require_attr(attrs, name, on)
  match parse_signed_int(raw) {
    Some(n) => @units.Percentage::from_ooxml(n)
    None =>
      raise XmlReadError(
        on + " attribute " + name + " is not an integer: " + raw,
      )
  }
}
