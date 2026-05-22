// `.rels` files — the OPC relationship catalog.
//
// Schema (excerpt) per ISO/IEC 29500-2 §10.1.2.4:
//   <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
//     <Relationship Id="rId1" Type="…" Target="…"/>
//     <Relationship Id="rId2" Type="…" Target="http://…" TargetMode="External"/>
//   </Relationships>
//
// Each part may have its own `.rels` file describing typed links to other
// parts (or to external resources). The package itself also has a top-level
// `/_rels/.rels` for entry-point relationships.
//
// Layout in the package:
//   * Package-level: `/_rels/.rels`
//   * Part `/foo/bar.xml`: `/foo/_rels/bar.xml.rels`

///|
/// Namespace URI of `.rels` files.
pub let relationships_ns : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
/// Logical "source" name used for the package-level relationships.
pub let package_root : String = "/"

///|
/// Whether a relationship target is internal (another part in the package)
/// or external (a URI).
pub(all) enum TargetMode {
  Internal
  External
} derive(Eq, Debug)

///|
/// A single typed link from one part (or the package) to another resource.
///
/// `id` is the local key (`"rId1"`, `"rId7"`). `rel_type` is the
/// relationship type URI (e.g.
/// `…/officeDocument/2006/relationships/officeDocument`). `target` is a
/// part-name fragment, relative to the source's directory unless absolute
/// (starts with `/`) or `target_mode == External`.
pub(all) struct Relationship {
  id : String
  rel_type : String
  target : String
  target_mode : TargetMode
} derive(Eq, Debug)

///|
pub impl Show for Relationship with fn output(self, logger) {
  logger.write_string("Relationship(")
  logger.write_object(self.id)
  logger.write_string(", ")
  logger.write_object(self.rel_type)
  logger.write_string(" -> ")
  logger.write_object(self.target)
  match self.target_mode {
    Internal => ()
    External => logger.write_string(" [External]")
  }
  logger.write_string(")")
}

///|
/// All relationships originating from one source (part or package).
///
/// `source` is the OPC name of the originating part, or `"/"` for the
/// package-level relationships. Lookup helpers (`by_id` / `by_type`) and an
/// immutable builder (`with_relationship`) are provided.
pub(all) struct Relationships {
  source : String
  items : Array[Relationship]
} derive(Debug)

///|
pub fn Relationships::new(source : String) -> Relationships {
  { source, items: [] }
}

///|
/// Parse a `.rels` file. `source` is the OPC name of the part the rels
/// belong to (use `package_root` for `/_rels/.rels`).
pub fn Relationships::parse(
  source : String,
  bytes : FixedArray[Byte],
) -> Relationships raise OpcError {
  let text = @fzip.str_from_u8(bytes) catch { e => raise wrap_fzip(e) }
  parse_relationships_xml(source, text)
}

///|
/// Serialize back to `.rels` bytes (UTF-8).
pub fn Relationships::serialize(
  self : Relationships,
) -> FixedArray[Byte] raise OpcError {
  let xml = serialize_relationships_xml(self) catch {
    e => raise MalformedPackage("relationships writer error: " + e.to_string())
  }
  @fzip.str_to_u8(xml)
}

///|
/// Look up a relationship by its `Id`. Returns `None` if no such Id exists.
pub fn Relationships::by_id(self : Relationships, id : String) -> Relationship? {
  for r in self.items {
    if r.id == id {
      return Some(r)
    }
  }
  None
}

///|
/// Return all relationships of a given type, in source order.
pub fn Relationships::by_type(
  self : Relationships,
  rel_type : String,
) -> Array[Relationship] {
  let out : Array[Relationship] = []
  for r in self.items {
    if r.rel_type == rel_type {
      out.push(r)
    }
  }
  out
}

///|
/// Return a new `Relationships` with `rel` appended. Raises if a relationship
/// with the same `Id` already exists.
pub fn Relationships::with_relationship(
  self : Relationships,
  rel : Relationship,
) -> Relationships raise OpcError {
  for existing in self.items {
    if existing.id == rel.id {
      raise MalformedPackage(
        "duplicate relationship id `" +
        rel.id +
        "` for source `" +
        self.source +
        "`",
      )
    }
  }
  let next : Array[Relationship] = Array::new(capacity=self.items.length() + 1)
  for r in self.items {
    next.push(r)
  }
  next.push(rel)
  { source: self.source, items: next }
}

///|
/// Resolve a relationship's `target` against a `source` part name to an
/// absolute OPC part name. Returns the input unchanged for external
/// relationships.
///
/// Examples (with source `"/ppt/presentation.xml"`):
///   * `"slides/slide1.xml"`  → `"/ppt/slides/slide1.xml"`
///   * `"../media/image1.png"` → `"/media/image1.png"`
///   * `"/foo/bar.xml"`        → `"/foo/bar.xml"`
pub fn resolve_target(
  source : String,
  target : String,
  target_mode : TargetMode,
) -> String {
  match target_mode {
    External => return target
    Internal => ()
  }
  let tchars = target.to_array()
  // Already absolute.
  if tchars.length() > 0 && tchars[0] == '/' {
    return target
  }
  // Take the directory portion of source (everything up to and including the
  // last `/`).
  let schars = source.to_array()
  let mut last_slash = -1
  let mut i = 0
  while i < schars.length() {
    if schars[i] == '/' {
      last_slash = i
    }
    i = i + 1
  }
  if last_slash < 0 {
    // Source had no `/` — should not happen for well-formed OPC names.
    return "/" + target
  }
  let dir_chars : Array[Char] = []
  let mut j = 0
  while j <= last_slash {
    dir_chars.push(schars[j])
    j = j + 1
  }
  // Resolve `..` segments inside `target`.
  let segments : Array[Array[Char]] = []
  // Seed segments with the directory's segments (excluding leading "/").
  let mut k = 1
  let mut current : Array[Char] = []
  while k < dir_chars.length() {
    if dir_chars[k] == '/' {
      if current.length() > 0 {
        segments.push(current)
        current = []
      }
    } else {
      current.push(dir_chars[k])
    }
    k = k + 1
  }
  // Now process the target's segments.
  let mut t = 0
  current = []
  while t <= tchars.length() {
    if t == tchars.length() || tchars[t] == '/' {
      let seg_chars = current
      current = []
      if seg_chars.length() == 0 {
        // skip empty segments
      } else if is_dot_segment(seg_chars) {
        // "." → no-op
      } else if is_dot_dot_segment(seg_chars) {
        if segments.length() > 0 {
          let _ = segments.pop().unwrap()
        }
      } else {
        segments.push(seg_chars)
      }
      if t == tchars.length() {
        break
      }
    } else {
      current.push(tchars[t])
    }
    t = t + 1
  }
  // Reassemble.
  let buf = StringBuilder::new(size_hint=64)
  for seg in segments {
    buf.write_char('/')
    for c in seg {
      buf.write_char(c)
    }
  }
  let result = buf.to_string()
  if result.length() == 0 {
    "/"
  } else {
    result
  }
}

///|
/// Return the OPC part name where the `.rels` file for `source` lives.
///
/// * `package_root` (`"/"`) → `"/_rels/.rels"`
/// * `"/foo/bar.xml"`       → `"/foo/_rels/bar.xml.rels"`
pub fn rels_path_for(source : String) -> String {
  if source == package_root {
    return "/_rels/.rels"
  }
  let chars = source.to_array()
  // Find last `/` to split into dir and base name.
  let mut last_slash = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '/' {
      last_slash = i
    }
    i = i + 1
  }
  if last_slash < 0 {
    return "/_rels/" + source + ".rels"
  }
  let buf = StringBuilder::new(size_hint=chars.length() + 12)
  let mut j = 0
  while j <= last_slash {
    buf.write_char(chars[j])
    j = j + 1
  }
  buf.write_string("_rels/")
  while j < chars.length() {
    buf.write_char(chars[j])
    j = j + 1
  }
  buf.write_string(".rels")
  buf.to_string()
}

// --- internal ---

///|
fn is_dot_segment(seg : Array[Char]) -> Bool {
  seg.length() == 1 && seg[0] == '.'
}

///|
fn is_dot_dot_segment(seg : Array[Char]) -> Bool {
  seg.length() == 2 && seg[0] == '.' && seg[1] == '.'
}

///|
fn parse_relationships_xml(
  source : String,
  xml : String,
) -> Relationships raise OpcError {
  let r = @xml.XmlReader::new(xml)
  let items : Array[Relationship] = []
  let mut saw_root = false
  while true {
    let event = r.next() catch {
      e =>
        raise MalformedPackage(
          "relationships XML is malformed: " + e.to_string(),
        )
    }
    match event {
      Some(StartElement(name, attrs)) => {
        if name.uri != relationships_ns {
          raise MalformedPackage(
            "relationships element in unexpected namespace: " + name.uri,
          )
        }
        match name.local_name {
          "Relationships" => saw_root = true
          "Relationship" => {
            if !saw_root {
              raise MalformedPackage("Relationship outside Relationships root")
            }
            let id = require_attr(attrs, "Id")
            let rel_type = require_attr(attrs, "Type")
            let target = require_attr(attrs, "Target")
            let mode = optional_attr(attrs, "TargetMode")
            let target_mode = match mode {
              "" => Internal
              "Internal" => Internal
              "External" => External
              other =>
                raise MalformedPackage("unknown TargetMode value: " + other)
            }
            items.push({ id, rel_type, target, target_mode })
          }
          other =>
            raise MalformedPackage("unexpected element in .rels: " + other)
        }
      }
      Some(EndElement(_)) => ()
      Some(Text(_)) => ()
      Some(CData(_)) => ()
      None => break
    }
  }
  if !saw_root {
    raise MalformedPackage("relationships XML missing <Relationships> root")
  }
  { source, items }
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

///|
fn serialize_relationships_xml(
  rels : Relationships,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("", relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(relationships_ns, "Relationships"))
  w.default_namespace_attr(relationships_ns)
  for r in rels.items {
    w.start_element(@xml.QName::new(relationships_ns, "Relationship"))
    w.attribute(@xml.QName::unqualified("Id"), r.id)
    w.attribute(@xml.QName::unqualified("Type"), r.rel_type)
    w.attribute(@xml.QName::unqualified("Target"), r.target)
    match r.target_mode {
      Internal => () // omit when Internal (the OPC default)
      External => w.attribute(@xml.QName::unqualified("TargetMode"), "External")
    }
    w.end_element()
  }
  w.end_element()
  w.to_string()
}
