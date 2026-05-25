// Streaming XML writer.
//
// Designed for OOXML output: compact (no insignificant whitespace), explicit
// namespace prefix bindings, attribute and text escaping, and auto-collapsing
// empty elements (`<foo/>`).
//
// Usage sketch:
//   let w = XmlWriter::new()
//   w.xml_declaration()
//   w.bind_namespace("a", a_uri)
//   w.start_element(QName::new(a_uri, "rect"))
//   w.namespace_attr("a", a_uri)
//   w.attribute(QName::unqualified("id"), "1")
//   w.text("hello")
//   w.end_element()
//   let xml = w.to_string()

///|
/// Streaming XML writer. Emits well-formed XML to an internal buffer.
pub struct XmlWriter {
  buf : StringBuilder
  prefix_for_uri : Map[String, String]
  stack : Array[QName]
  // True while we are inside a just-opened start tag (the `>` has not yet been
  // emitted, so attributes are still allowed and the element can self-close).
  mut in_start_tag : Bool
}

///|
/// Construct a new streaming XML writer with an empty buffer.
pub fn XmlWriter::new() -> XmlWriter {
  {
    buf: StringBuilder::new(size_hint=256),
    prefix_for_uri: Map([]),
    stack: Array::new(),
    in_start_tag: false,
  }
}

///|
/// Register a namespace prefix for a URI. This affects how `QName`s in that
/// URI are serialised (`<prefix:local …>`). It does *not* emit `xmlns:…`
/// declarations — call `namespace_attr` for that, typically on the root.
pub fn XmlWriter::bind_namespace(
  self : XmlWriter,
  prefix : String,
  uri : String,
) -> Unit {
  self.prefix_for_uri[uri] = prefix
}

///|
/// Emit `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`. Call once
/// at the very start of the document (before any `start_element`).
pub fn XmlWriter::xml_declaration(self : XmlWriter) -> Unit {
  self.buf.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
  )
}

///|
/// Open a new element. Pushes onto the element stack.
pub fn XmlWriter::start_element(
  self : XmlWriter,
  name : QName,
) -> Unit raise XmlError {
  self.close_start_tag(self_close=false)
  self.buf.write_char('<')
  self.write_qname(name)
  self.stack.push(name)
  self.in_start_tag = true
}

///|
/// Emit an attribute. Must be called while still inside the most recent
/// start tag — between `start_element` and any `text` / `cdata` / child
/// `start_element`. Raises `WriterMisuse` otherwise.
pub fn XmlWriter::attribute(
  self : XmlWriter,
  name : QName,
  value : String,
) -> Unit raise XmlError {
  if !self.in_start_tag {
    raise WriterMisuse("attribute() called outside an open start tag")
  }
  self.buf.write_char(' ')
  self.write_qname(name)
  self.buf.write_string("=\"")
  write_escaped_attr(self.buf, value)
  self.buf.write_char('"')
}

///|
/// Emit `xmlns:prefix="uri"` on the current open start tag. Convenience for
/// the common case of declaring a prefix on root.
pub fn XmlWriter::namespace_attr(
  self : XmlWriter,
  prefix : String,
  uri : String,
) -> Unit raise XmlError {
  if !self.in_start_tag {
    raise WriterMisuse("namespace_attr() called outside an open start tag")
  }
  self.buf.write_string(" xmlns:")
  self.buf.write_string(prefix)
  self.buf.write_string("=\"")
  write_escaped_attr(self.buf, uri)
  self.buf.write_char('"')
}

///|
/// Emit `xmlns="uri"` (default namespace declaration) on the current open start tag.
pub fn XmlWriter::default_namespace_attr(
  self : XmlWriter,
  uri : String,
) -> Unit raise XmlError {
  if !self.in_start_tag {
    raise WriterMisuse(
      "default_namespace_attr() called outside an open start tag",
    )
  }
  self.buf.write_string(" xmlns=\"")
  write_escaped_attr(self.buf, uri)
  self.buf.write_char('"')
}

///|
/// Emit text content inside the current element. The text is XML-escaped.
pub fn XmlWriter::text(self : XmlWriter, s : String) -> Unit raise XmlError {
  if self.stack.length() == 0 {
    raise WriterMisuse("text() called with no element open")
  }
  self.close_start_tag(self_close=false)
  write_escaped_text(self.buf, s)
}

///|
/// Emit a CDATA section. The payload must not contain `]]>`.
pub fn XmlWriter::cdata(self : XmlWriter, s : String) -> Unit raise XmlError {
  if self.stack.length() == 0 {
    raise WriterMisuse("cdata() called with no element open")
  }
  if contains_cdata_terminator(s) {
    raise WriterMisuse("cdata() payload contains the literal `]]>`")
  }
  self.close_start_tag(self_close=false)
  self.buf.write_string("<![CDATA[")
  self.buf.write_string(s)
  self.buf.write_string("]]>")
}

///|
/// Close the most recently opened element. Self-closes (`<foo/>`) if no
/// children or text were written.
pub fn XmlWriter::end_element(self : XmlWriter) -> Unit raise XmlError {
  if self.stack.length() == 0 {
    raise WriterMisuse("end_element() with no element open")
  }
  let name = self.stack.pop().unwrap()
  if self.in_start_tag {
    // Empty element — collapse to <foo/>.
    self.buf.write_string("/>")
    self.in_start_tag = false
  } else {
    self.buf.write_string("</")
    self.write_qname(name)
    self.buf.write_char('>')
  }
}

///|
/// Finalise and return the document text. Raises if any element is still
/// open (i.e. `start_element` calls are not balanced by `end_element`).
pub fn XmlWriter::to_string(self : XmlWriter) -> String raise XmlError {
  if self.stack.length() != 0 {
    raise WriterMisuse(
      "to_string() called with " +
      self.stack.length().to_string() +
      " elements still open",
    )
  }
  self.buf.to_string()
}

// --- internal helpers ---

///|
fn XmlWriter::close_start_tag(self : XmlWriter, self_close~ : Bool) -> Unit {
  if self.in_start_tag {
    if self_close {
      self.buf.write_string("/>")
    } else {
      self.buf.write_char('>')
    }
    self.in_start_tag = false
  }
}

///|
fn XmlWriter::write_qname(
  self : XmlWriter,
  name : QName,
) -> Unit raise XmlError {
  if name.uri.length() == 0 {
    self.buf.write_string(name.local_name)
  } else {
    match self.prefix_for_uri.get(name.uri) {
      Some(prefix) => {
        if prefix.length() > 0 {
          self.buf.write_string(prefix)
          self.buf.write_char(':')
        }
        self.buf.write_string(name.local_name)
      }
      None => raise UnboundPrefix(name.uri)
    }
  }
}

///|
fn write_escaped_attr(buf : StringBuilder, s : String) -> Unit {
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      '\n' => buf.write_string("&#10;")
      '\r' => buf.write_string("&#13;")
      '\t' => buf.write_string("&#9;")
      _ => buf.write_char(c)
    }
  }
}

///|
fn write_escaped_text(buf : StringBuilder, s : String) -> Unit {
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(c)
    }
  }
}

///|
fn contains_cdata_terminator(s : String) -> Bool {
  // Look for `]]>` as a literal substring. We don't need a fast search here
  // since CDATA bodies are usually small.
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  while i + 2 < n {
    if chars[i] == ']' && chars[i + 1] == ']' && chars[i + 2] == '>' {
      return true
    }
    i = i + 1
  }
  false
}
