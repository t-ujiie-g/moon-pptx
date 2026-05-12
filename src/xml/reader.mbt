// Streaming, event-based XML reader.
//
// `XmlReader::next()` returns one event at a time, lazily walking the input.
// We chose events over a DOM (see ADR-008 in TODO.md) because:
//   * OOXML files are large; a DOM holds the whole tree in memory.
//   * Most readers care about a small subset of element kinds and benefit
//     from skipping the rest cheaply.
//   * A DOM can always be built on top of events when needed; the reverse
//     is harder.
//
// Coverage:
//   * Elements with attributes; namespace prefix resolution via in-scope
//     `xmlns:*` declarations and `xmlns=...` default declarations.
//   * Self-closing elements emit StartElement + EndElement back to back.
//   * Text content with entity decoding (`&amp; &lt; &gt; &quot; &apos;`
//     and numeric `&#NN;` / `&#xNN;`).
//   * CDATA sections; comments and processing instructions are skipped
//     (the `<?xml … ?>` declaration is also skipped).
//   * Malformed input raises typed `XmlError`.

///|
/// One reader event. Attributes on `StartElement` are reported in source
/// order; values are already entity-decoded.
pub(all) enum XmlEvent {
  StartElement(QName, Array[(QName, String)])
  EndElement(QName)
  Text(String)
  CData(String)
} derive(Debug)

///|
pub impl Show for XmlEvent with output(self, logger) {
  match self {
    StartElement(n, _) => {
      logger.write_string("StartElement(")
      logger.write_object(n)
      logger.write_string(")")
    }
    EndElement(n) => {
      logger.write_string("EndElement(")
      logger.write_object(n)
      logger.write_string(")")
    }
    Text(s) => {
      logger.write_string("Text(")
      logger.write_object(s)
      logger.write_string(")")
    }
    CData(s) => {
      logger.write_string("CData(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}

///|
/// Streaming XML reader.
pub struct XmlReader {
  chars : Array[Char]
  mut pos : Int
  // One Map per open element. `ns_stack[0]` holds bindings declared on the
  // root element. Lookups walk from top to bottom (most-recent wins).
  ns_stack : Array[Map[String, String]]
  // Element name stack for matching end tags and emitting EndElement after
  // a self-closing start.
  element_stack : Array[QName]
  // Queued events from a previous step (e.g. EndElement after a self-close,
  // or both StartElement and EndElement of an empty self-close).
  pending : Array[XmlEvent]
}

///|
/// Construct a reader over the given input string.
pub fn XmlReader::new(input : String) -> XmlReader {
  {
    chars: input.to_array(),
    pos: 0,
    ns_stack: Array::new(),
    element_stack: Array::new(),
    pending: Array::new(),
  }
}

///|
/// Return the next event, or `None` at end of input. Raises `XmlError`
/// for malformed input.
pub fn XmlReader::next(self : XmlReader) -> XmlEvent? raise XmlError {
  if self.pending.length() > 0 {
    return Some(self.pending.remove(0))
  }
  // Consume leading whitespace at the document level.
  if self.element_stack.length() == 0 {
    self.skip_whitespace()
  }
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if c == '<' {
      let next_c = self.peek_at(self.pos + 1)
      match next_c {
        Some('?') => self.skip_pi()
        Some('!') =>
          if self.starts_with(self.pos, "<!--") {
            self.skip_comment()
          } else if self.starts_with(self.pos, "<![CDATA[") {
            return Some(self.read_cdata())
          } else {
            // <!DOCTYPE …> — skip to next '>'
            self.skip_to_char('>')
            self.advance() // consume the '>'
          }
        Some('/') => return Some(self.read_end_tag())
        Some(_) => return Some(self.read_start_tag())
        None => raise UnexpectedEof
      }
    } else {
      // Text content
      let t = self.read_text()
      if t.length() == 0 {
        // Was all whitespace between elements at root level — keep scanning.
        continue
      }
      return Some(Text(t))
    }
  }
  if self.element_stack.length() != 0 {
    raise UnexpectedEof
  }
  None
}

// --- input cursor helpers ---

///|
fn XmlReader::peek_at(self : XmlReader, i : Int) -> Char? {
  if i < self.chars.length() {
    Some(self.chars[i])
  } else {
    None
  }
}

///|
fn XmlReader::advance(self : XmlReader) -> Unit {
  self.pos = self.pos + 1
}

///|
fn XmlReader::starts_with(
  self : XmlReader,
  start : Int,
  needle : String,
) -> Bool {
  let nchars = needle.to_array()
  let n = nchars.length()
  if start + n > self.chars.length() {
    return false
  }
  let mut i = 0
  while i < n {
    if self.chars[start + i] != nchars[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn XmlReader::skip_whitespace(self : XmlReader) -> Unit {
  while self.pos < self.chars.length() && is_xml_space(self.chars[self.pos]) {
    self.advance()
  }
}

///|
fn XmlReader::skip_to_char(self : XmlReader, target : Char) -> Unit {
  while self.pos < self.chars.length() && self.chars[self.pos] != target {
    self.advance()
  }
}

///|
fn is_xml_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_name_start_char(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  c == '_' ||
  c == ':' ||
  code > 127
}

///|
fn is_name_char(c : Char) -> Bool {
  let code = c.to_int()
  is_name_start_char(c) ||
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  c == '-' ||
  c == '.'
}

// --- skip non-content nodes ---

///|
fn XmlReader::skip_pi(self : XmlReader) -> Unit raise XmlError {
  // We're at `<?`. Advance past it and consume up to the closing `?>`.
  self.advance()
  self.advance()
  while self.pos + 1 < self.chars.length() {
    if self.chars[self.pos] == '?' && self.chars[self.pos + 1] == '>' {
      self.advance()
      self.advance()
      return
    }
    self.advance()
  }
  raise UnexpectedEof
}

///|
fn XmlReader::skip_comment(self : XmlReader) -> Unit raise XmlError {
  // We're at `<!--`. Skip past it.
  self.pos = self.pos + 4
  while self.pos + 2 < self.chars.length() {
    if self.chars[self.pos] == '-' &&
      self.chars[self.pos + 1] == '-' &&
      self.chars[self.pos + 2] == '>' {
      self.pos = self.pos + 3
      return
    }
    self.advance()
  }
  raise UnexpectedEof
}

// --- start / end / cdata / text ---

///|
fn XmlReader::read_start_tag(self : XmlReader) -> XmlEvent raise XmlError {
  // Skip the opening '<'.
  self.advance()
  let prefixed = self.read_name()
  // Push a new scope for namespace declarations made on this element.
  let scope : Map[String, String] = Map::new(capacity=0)
  // Collect raw attributes; we resolve QNames *after* gathering the scope
  // so that `xmlns:*` decls on this element apply to its own attributes.
  let raw_attrs : Array[(String, String)] = Array::new()
  while self.pos < self.chars.length() {
    self.skip_whitespace()
    let c = self.chars[self.pos]
    if c == '>' {
      self.advance()
      break
    } else if c == '/' {
      // Self-closing: expect "/>"
      if self.pos + 1 >= self.chars.length() || self.chars[self.pos + 1] != '>' {
        raise Malformed("expected `/>` to close self-closing element")
      }
      self.advance()
      self.advance()
      let qname = self.resolve_qname(prefixed, scope, is_attribute=false)
      // Push then immediately mirror an EndElement.
      self.ns_stack.push(scope)
      self.element_stack.push(qname)
      self.pending.push(EndElement(qname))
      // Synthesize the EndElement removal: we still pop on subsequent EndElement event.
      let attrs = self.resolve_attrs(raw_attrs, scope)
      // But we must also pop after the EndElement is consumed. The consumer
      // will call next() and pull EndElement, but the stack pop happens here
      // synchronously to keep state consistent for any further parsing.
      let _ = self.element_stack.pop().unwrap()
      let _ = self.ns_stack.pop().unwrap()
      return StartElement(qname, attrs)
    } else {
      let attr_name = self.read_name()
      self.skip_whitespace()
      if self.pos >= self.chars.length() || self.chars[self.pos] != '=' {
        raise Malformed("expected `=` after attribute name `" + attr_name + "`")
      }
      self.advance()
      self.skip_whitespace()
      let value = self.read_attr_value()
      // Special-case namespace declarations.
      if attr_name == "xmlns" {
        scope[""] = value
      } else if attr_name.length() > 6 && starts_with_str(attr_name, "xmlns:") {
        let prefix = drop_prefix(attr_name, 6)
        scope[prefix] = value
      } else {
        raw_attrs.push((attr_name, value))
      }
    }
  }
  let qname = self.resolve_qname(prefixed, scope, is_attribute=false)
  self.ns_stack.push(scope)
  self.element_stack.push(qname)
  let attrs = self.resolve_attrs(raw_attrs, scope)
  StartElement(qname, attrs)
}

///|
fn XmlReader::read_end_tag(self : XmlReader) -> XmlEvent raise XmlError {
  // Skip the opening "</"
  self.advance()
  self.advance()
  let prefixed = self.read_name()
  self.skip_whitespace()
  if self.pos >= self.chars.length() || self.chars[self.pos] != '>' {
    raise Malformed("expected `>` after end tag name `" + prefixed + "`")
  }
  self.advance()
  // Resolve against the *current* scope (the element being closed).
  let scope = if self.ns_stack.length() > 0 {
    self.ns_stack[self.ns_stack.length() - 1]
  } else {
    Map::new(capacity=0)
  }
  let qname = self.resolve_qname(prefixed, scope, is_attribute=false)
  if self.element_stack.length() == 0 {
    raise MismatchedEndTag(prefixed)
  }
  let opened = self.element_stack[self.element_stack.length() - 1]
  if opened != qname {
    raise MismatchedEndTag(prefixed)
  }
  let _ = self.element_stack.pop().unwrap()
  let _ = self.ns_stack.pop().unwrap()
  EndElement(qname)
}

///|
fn XmlReader::read_cdata(self : XmlReader) -> XmlEvent raise XmlError {
  // Skip `<![CDATA[`
  self.pos = self.pos + 9
  let start = self.pos
  while self.pos + 2 < self.chars.length() {
    if self.chars[self.pos] == ']' &&
      self.chars[self.pos + 1] == ']' &&
      self.chars[self.pos + 2] == '>' {
      let body = chars_to_string(self.chars, start, self.pos)
      self.pos = self.pos + 3
      return CData(body)
    }
    self.advance()
  }
  raise UnexpectedEof
}

///|
fn XmlReader::read_text(self : XmlReader) -> String raise XmlError {
  let buf = StringBuilder::new(size_hint=32)
  let mut all_space = true
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if c == '<' {
      break
    }
    if !is_xml_space(c) {
      all_space = false
    }
    if c == '&' {
      let decoded = self.read_entity()
      buf.write_string(decoded)
    } else {
      buf.write_char(c)
      self.advance()
    }
  }
  // At root scope, ignore inter-element whitespace by returning empty.
  if self.element_stack.length() == 0 && all_space {
    return ""
  }
  buf.to_string()
}

///|
fn XmlReader::read_attr_value(self : XmlReader) -> String raise XmlError {
  if self.pos >= self.chars.length() {
    raise UnexpectedEof
  }
  let quote = self.chars[self.pos]
  if quote != '"' && quote != '\'' {
    raise Malformed("expected attribute value to start with a quote")
  }
  self.advance()
  let buf = StringBuilder::new(size_hint=16)
  while self.pos < self.chars.length() && self.chars[self.pos] != quote {
    let c = self.chars[self.pos]
    if c == '&' {
      buf.write_string(self.read_entity())
    } else {
      buf.write_char(c)
      self.advance()
    }
  }
  if self.pos >= self.chars.length() {
    raise UnexpectedEof
  }
  self.advance() // consume closing quote
  buf.to_string()
}

///|
fn XmlReader::read_entity(self : XmlReader) -> String raise XmlError {
  // Caller has confirmed self.chars[pos] == '&'
  self.advance()
  let start = self.pos
  while self.pos < self.chars.length() && self.chars[self.pos] != ';' {
    self.advance()
  }
  if self.pos >= self.chars.length() {
    raise UnexpectedEof
  }
  let name = chars_to_string(self.chars, start, self.pos)
  self.advance() // consume ';'
  match name {
    "amp" => "&"
    "lt" => "<"
    "gt" => ">"
    "quot" => "\""
    "apos" => "'"
    _ => decode_numeric_entity(name)
  }
}

///|
fn decode_numeric_entity(name : String) -> String raise XmlError {
  let chars = name.to_array()
  if chars.length() < 2 || chars[0] != '#' {
    raise Malformed("unknown entity reference `&" + name + ";`")
  }
  let (radix, start) = if chars[1] == 'x' || chars[1] == 'X' {
    (16, 2)
  } else {
    (10, 1)
  }
  let mut value = 0
  let mut i = start
  while i < chars.length() {
    let d = match chars[i] {
      '0'..='9' => chars[i].to_int() - '0'.to_int()
      'a'..='f' => chars[i].to_int() - 'a'.to_int() + 10
      'A'..='F' => chars[i].to_int() - 'A'.to_int() + 10
      _ => raise Malformed("bad digit in numeric entity `&" + name + ";`")
    }
    if d >= radix {
      raise Malformed("bad digit in numeric entity `&" + name + ";`")
    }
    value = value * radix + d
    i = i + 1
  }
  match value.to_char() {
    Some(c) => String::from_array([c])
    None => raise Malformed("invalid code point in `&" + name + ";`")
  }
}

// --- name / qname resolution ---

///|
fn XmlReader::read_name(self : XmlReader) -> String raise XmlError {
  if self.pos >= self.chars.length() ||
    !is_name_start_char(self.chars[self.pos]) {
    raise Malformed("expected XML name")
  }
  let start = self.pos
  while self.pos < self.chars.length() && is_name_char(self.chars[self.pos]) {
    self.advance()
  }
  chars_to_string(self.chars, start, self.pos)
}

///|
fn XmlReader::resolve_qname(
  self : XmlReader,
  prefixed : String,
  scope : Map[String, String],
  is_attribute~ : Bool,
) -> QName raise XmlError {
  let chars = prefixed.to_array()
  let mut colon = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == ':' {
      colon = i
      break
    }
    i = i + 1
  }
  if colon < 0 {
    // No prefix.
    if is_attribute {
      // Default namespace does not apply to unprefixed attributes.
      return QName::unqualified(prefixed)
    }
    let uri = self.lookup_ns("", scope)
    QName::new(uri, prefixed)
  } else {
    let prefix = chars_to_string(chars, 0, colon)
    let local_name = chars_to_string(chars, colon + 1, chars.length())
    let uri = match scope.get(prefix) {
      Some(v) => v
      None => self.lookup_ns(prefix, scope)
    }
    if uri.length() == 0 {
      raise UnboundPrefix(prefix)
    }
    QName::new(uri, local_name)
  }
}

///|
fn XmlReader::lookup_ns(
  self : XmlReader,
  prefix : String,
  current_scope : Map[String, String],
) -> String {
  match current_scope.get(prefix) {
    Some(v) => return v
    None => ()
  }
  let mut i = self.ns_stack.length() - 1
  while i >= 0 {
    match self.ns_stack[i].get(prefix) {
      Some(v) => return v
      None => ()
    }
    i = i - 1
  }
  ""
}

///|
fn XmlReader::resolve_attrs(
  self : XmlReader,
  raw : Array[(String, String)],
  scope : Map[String, String],
) -> Array[(QName, String)] raise XmlError {
  let out : Array[(QName, String)] = Array::new(capacity=raw.length())
  for kv in raw {
    let q = self.resolve_qname(kv.0, scope, is_attribute=true)
    out.push((q, kv.1))
  }
  out
}

// --- shared string helpers ---

///|
fn chars_to_string(chars : Array[Char], start : Int, stop : Int) -> String {
  let buf = StringBuilder::new(size_hint=stop - start)
  let mut i = start
  while i < stop {
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
fn starts_with_str(s : String, prefix : String) -> Bool {
  let sc = s.to_array()
  let pc = prefix.to_array()
  if sc.length() < pc.length() {
    return false
  }
  let mut i = 0
  while i < pc.length() {
    if sc[i] != pc[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn drop_prefix(s : String, n : Int) -> String {
  let chars = s.to_array()
  chars_to_string(chars, n, chars.length())
}
