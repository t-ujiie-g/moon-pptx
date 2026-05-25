// Shared chart-namespace attribute helpers.
//
// Every typed body parser (axis / title / legend / dLbls / dLbl /
// series) needs to read `val="…"` attributes off captured leaf
// elements like `<c:axId val="1"/>` / `<c:showVal val="1"/>` /
// `<c:dLblPos val="ctr"/>`. Likewise every writer needs to emit the
// same shape. These helpers consolidate that shared mechanics so
// each body file only carries domain logic.
//
// All helpers in this file are file-private — MoonBit treats top-
// level non-`pub` declarations as package-private (visible across
// every `.mbt` file in the chart package), so consumers do not need
// to import or qualify them.

///|
/// Read a `val="…"` attribute off a captured leaf element and parse
/// it as an `Int`. Returns `None` if the attribute is absent or
/// unparseable.
fn val_int(el : @xml.XmlElement) -> Int? {
  for kv in el.attributes {
    if kv.0.local_name == "val" {
      return @oxml.parse_signed_int(kv.1)
    }
  }
  None
}

///|
/// Read a `val="…"` attribute and parse it as a Bool. Accepts the
/// schema-permitted lexical forms `1`/`true`/`0`/`false`; anything
/// else (or absent) yields `None`.
fn val_bool(el : @xml.XmlElement) -> Bool? {
  for kv in el.attributes {
    if kv.0.local_name == "val" {
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
/// Read a `val="…"` attribute as a raw String. Returns `None` when
/// the attribute is absent.
fn val_string(el : @xml.XmlElement) -> String? {
  for kv in el.attributes {
    if kv.0.local_name == "val" {
      return Some(kv.1)
    }
  }
  None
}

///|
/// Emit a `<c:foo val="…"/>` leaf for an Int value.
fn emit_val_int(
  w : @xml.XmlWriter,
  local_name : String,
  v : Int,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), v.to_string())
  w.end_element()
}

///|
/// Emit a `<c:foo val="…"/>` leaf for a Bool value (canonical
/// `"1"`/`"0"` lexical form on write).
fn emit_val_bool(
  w : @xml.XmlWriter,
  local_name : String,
  v : Bool,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), if v { "1" } else { "0" })
  w.end_element()
}

///|
/// Emit a `<c:foo val="…"/>` leaf for a String value (already
/// schema-conformant — e.g. the enum's `to_xml()` output).
fn emit_val_string(
  w : @xml.XmlWriter,
  local_name : String,
  v : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, local_name))
  w.attribute(@xml.QName::unqualified("val"), v)
  w.end_element()
}
