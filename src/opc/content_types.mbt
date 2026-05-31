// `[Content_Types].xml` — the OPC content-type catalog.
//
// Schema (excerpt) per ISO/IEC 29500-2 §10.1.2.2:
//   <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
//     <Default Extension="rels" ContentType="…"/>
//     <Default Extension="xml"  ContentType="…"/>
//     <Override PartName="/ppt/presentation.xml" ContentType="…"/>
//   </Types>
//
// Resolution for a given part name is: matching `Override` wins; otherwise
// the `Default` for the file extension applies; otherwise the content type
// is unknown.

///|
/// Namespace URI of `[Content_Types].xml`.
pub let content_types_ns : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
/// OPC part name that holds the content-type catalog. Always `/[Content_Types].xml`.
pub let content_types_part_name : String = "/[Content_Types].xml"

///|
/// Parsed `[Content_Types].xml`.
///
/// Entries are stored in source order; `with_default` / `with_override`
/// append. The struct is immutable in the OPC sense: builder methods return
/// a new value rather than mutating in place.
pub(all) struct ContentTypes {
  /// `(extension, content_type)` pairs. Extensions are stored as supplied
  /// (no case folding); lookup compares case-insensitively per the spec.
  defaults : Array[(String, String)]
  /// `(part_name, content_type)` pairs. Part names are case-sensitive.
  overrides : Array[(String, String)]
} derive(Eq, Debug)

///|
/// An empty catalog with no Default or Override entries.
pub fn ContentTypes::new() -> ContentTypes {
  { defaults: [], overrides: [] }
}

///|
/// Parse `[Content_Types].xml` from raw bytes.
pub fn ContentTypes::parse(
  bytes : FixedArray[Byte],
) -> ContentTypes raise OpcError {
  let text = @fzip.str_from_u8(bytes) catch { e => raise wrap_fzip(e) }
  parse_content_types_xml(text)
}

///|
/// Serialize back to `[Content_Types].xml` bytes (UTF-8).
pub fn ContentTypes::serialize(
  self : ContentTypes,
) -> FixedArray[Byte] raise OpcError {
  let xml = serialize_content_types_xml(self) catch {
    e => raise MalformedPackage("content types writer error: " + e.to_string())
  }
  @fzip.str_to_u8(xml)
}

///|
/// Resolve the content type for a part name, applying the OPC rules:
/// `Override` (case-sensitive on part name) wins; otherwise the `Default`
/// for the extension (case-insensitive). Returns `None` if neither matches.
pub fn ContentTypes::resolve(
  self : ContentTypes,
  part_name : String,
) -> String? {
  for kv in self.overrides {
    if kv.0 == part_name {
      return Some(kv.1)
    }
  }
  let ext = extension_of(part_name)
  if ext.length() == 0 {
    return None
  }
  for kv in self.defaults {
    if equals_ignore_case(kv.0, ext) {
      return Some(kv.1)
    }
  }
  None
}

///|
/// Return a new catalog with `(extension, content_type)` appended to the
/// `Default` list. Does not deduplicate; OPC allows but discourages
/// redundant entries.
pub fn ContentTypes::with_default(
  self : ContentTypes,
  extension : String,
  content_type : String,
) -> ContentTypes {
  let next : Array[(String, String)] = Array::new(
    capacity=self.defaults.length() + 1,
  )
  for kv in self.defaults {
    next.push(kv)
  }
  next.push((extension, content_type))
  { defaults: next, overrides: self.overrides }
}

///|
/// Return a new catalog with `(part_name, content_type)` appended to the
/// `Override` list.
pub fn ContentTypes::with_override(
  self : ContentTypes,
  part_name : String,
  content_type : String,
) -> ContentTypes {
  let next : Array[(String, String)] = Array::new(
    capacity=self.overrides.length() + 1,
  )
  for kv in self.overrides {
    next.push(kv)
  }
  next.push((part_name, content_type))
  { defaults: self.defaults, overrides: next }
}

///|
/// Return a new catalog with every `Override` for `part_name` dropped.
/// No-op (returns an equivalent catalog) when the part has no override —
/// images and other extension-typed parts use `Default` entries instead,
/// so removing them this way is intentionally harmless. Companion of
/// `with_override`, used when a part is deleted from the package.
pub fn ContentTypes::without_override(
  self : ContentTypes,
  part_name : String,
) -> ContentTypes {
  let next : Array[(String, String)] = Array::new(
    capacity=self.overrides.length(),
  )
  for kv in self.overrides {
    if kv.0 != part_name {
      next.push(kv)
    }
  }
  { defaults: self.defaults, overrides: next }
}

// --- internal ---

///|
/// Return the extension portion of a part name (the chars after the last
/// `.`, stopping at `/`). Returns the empty string if the basename has no
/// dot.
fn extension_of(name : String) -> String {
  let chars = name.to_array()
  let mut i = chars.length() - 1
  while i >= 0 && chars[i] != '.' && chars[i] != '/' {
    i = i - 1
  }
  if i < 0 || chars[i] != '.' {
    return ""
  }
  let buf = StringBuilder::new(size_hint=chars.length() - i - 1)
  let mut j = i + 1
  while j < chars.length() {
    buf.write_char(chars[j])
    j = j + 1
  }
  buf.to_string()
}

///|
fn equals_ignore_case(a : String, b : String) -> Bool {
  let ca = a.to_array()
  let cb = b.to_array()
  if ca.length() != cb.length() {
    return false
  }
  let mut i = 0
  while i < ca.length() {
    if to_lower_ascii(ca[i]) != to_lower_ascii(cb[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn to_lower_ascii(c : Char) -> Char {
  let code = c.to_int()
  if code >= 'A'.to_int() && code <= 'Z'.to_int() {
    (code + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn parse_content_types_xml(xml : String) -> ContentTypes raise OpcError {
  let r = @xml.XmlReader::new(xml)
  let defaults : Array[(String, String)] = []
  let overrides : Array[(String, String)] = []
  let mut saw_root = false
  while true {
    let event = r.next() catch {
      e =>
        raise MalformedPackage(
          "content types XML is malformed: " + e.to_string(),
        )
    }
    match event {
      Some(StartElement(name, attrs)) => {
        if name.uri != content_types_ns {
          raise MalformedPackage(
            "content types element in unexpected namespace: " + name.uri,
          )
        }
        match name.local_name {
          "Types" => saw_root = true
          "Default" => {
            if !saw_root {
              raise MalformedPackage("Default outside Types root")
            }
            let ext = require_attr(attrs, "Extension")
            let ct = require_attr(attrs, "ContentType")
            defaults.push((ext, ct))
          }
          "Override" => {
            if !saw_root {
              raise MalformedPackage("Override outside Types root")
            }
            let nm = require_attr(attrs, "PartName")
            let ct = require_attr(attrs, "ContentType")
            overrides.push((nm, ct))
          }
          other =>
            raise MalformedPackage(
              "unexpected element in [Content_Types].xml: " + other,
            )
        }
      }
      Some(EndElement(_)) => ()
      Some(Text(_)) => () // OPC content-types XML has no text content of interest
      Some(CData(_)) => ()
      None => break
    }
  }
  if !saw_root {
    raise MalformedPackage("content types XML missing <Types> root")
  }
  { defaults, overrides }
}

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  attr_name : String,
) -> String raise OpcError {
  for kv in attrs {
    if kv.0.local_name == attr_name {
      return kv.1
    }
  }
  raise MalformedPackage("missing required attribute: " + attr_name)
}

///|
fn serialize_content_types_xml(ct : ContentTypes) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("", content_types_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(content_types_ns, "Types"))
  w.default_namespace_attr(content_types_ns)
  for kv in ct.defaults {
    w.start_element(@xml.QName::new(content_types_ns, "Default"))
    w.attribute(@xml.QName::unqualified("Extension"), kv.0)
    w.attribute(@xml.QName::unqualified("ContentType"), kv.1)
    w.end_element()
  }
  for kv in ct.overrides {
    w.start_element(@xml.QName::new(content_types_ns, "Override"))
    w.attribute(@xml.QName::unqualified("PartName"), kv.0)
    w.attribute(@xml.QName::unqualified("ContentType"), kv.1)
    w.end_element()
  }
  w.end_element()
  w.to_string()
}
