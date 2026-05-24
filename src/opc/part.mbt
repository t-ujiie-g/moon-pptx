// OPC Part — one named blob inside a Package.
//
// Per OPC (ISO/IEC 29500-2), part names start with `/` and are case-sensitive
// path-style identifiers (e.g. `/ppt/presentation.xml`). The leading `/` is
// part of the OPC name but is NOT stored in the underlying ZIP entry name —
// helpers below convert between the two forms.

///|
/// One part inside an OPC package.
///
/// `name` is the OPC-style part name (always starts with `/`).
/// `content_type` is the MIME-like content type from `[Content_Types].xml`;
/// `Package::open` populates it via the ContentTypes resolver.
/// `bytes` is the raw payload (XML or binary).
pub(all) struct Part {
  name : String
  mut content_type : String
  bytes : FixedArray[Byte]
} derive(Debug)

///|
/// Construct a part with explicit fields. Name is validated.
pub fn Part::new(
  name : String,
  content_type : String,
  bytes : FixedArray[Byte],
) -> Part raise OpcError {
  validate_part_name(name)
  { name, content_type, bytes }
}

///|
/// Decode the payload as UTF-8 text. Raises `MalformedPackage` if the bytes
/// are not valid UTF-8. Convenience for the many OPC parts that hold XML.
pub fn Part::text(self : Part) -> String raise OpcError {
  @fzip.str_from_u8(self.bytes) catch {
    e => raise wrap_fzip(e)
  }
}

// --- name helpers (shared with Package) ---

///|
/// Convert an OPC part name (`/ppt/presentation.xml`) to its ZIP entry name
/// (`ppt/presentation.xml`).
pub fn opc_name_to_zip(name : String) -> String {
  if name.length() > 0 && name.to_array()[0] == '/' {
    string_drop(name, 1)
  } else {
    name
  }
}

///|
/// Convert a ZIP entry name (`ppt/presentation.xml`) to an OPC part name
/// (`/ppt/presentation.xml`).
pub fn zip_name_to_opc(zip_name : String) -> String {
  if zip_name.length() > 0 && zip_name.to_array()[0] == '/' {
    zip_name
  } else {
    "/" + zip_name
  }
}

///|
/// Validate that an OPC part name conforms to the basic shape required by
/// the spec: non-empty, starts with `/`, no trailing `/`, no empty segments.
pub fn validate_part_name(name : String) -> Unit raise OpcError {
  if name.length() == 0 {
    raise MalformedPackage("part name is empty")
  }
  let chars = name.to_array()
  if chars[0] != '/' {
    raise MalformedPackage("part name must start with `/`: " + name)
  }
  if chars.length() > 1 && chars[chars.length() - 1] == '/' {
    raise MalformedPackage("part name must not end with `/`: " + name)
  }
  let mut i = 1
  let mut prev_slash = false
  while i < chars.length() {
    if chars[i] == '/' {
      if prev_slash {
        raise MalformedPackage("part name has empty segment (`//`): " + name)
      }
      prev_slash = true
    } else {
      prev_slash = false
    }
    i = i + 1
  }
}

///|
fn string_drop(s : String, n : Int) -> String {
  let chars = s.to_array()
  let buf = StringBuilder::new(size_hint=chars.length() - n)
  let mut i = n
  while i < chars.length() {
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
pub impl Show for Part with fn output(self, logger) {
  logger.write_string("Part(")
  logger.write_object(self.name)
  if self.content_type.length() > 0 {
    logger.write_string(", ")
    logger.write_object(self.content_type)
  }
  logger.write_string(", ")
  logger.write_object(self.bytes.length())
  logger.write_string(" bytes)")
}
