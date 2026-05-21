// Comments XML readers — `commentAuthors.xml` and `commentsN.xml`.
//
// Same recursive-descent contract as `@theme` / `@slide_master` / `@slide`:
// every `parse_*` helper is called *just after* its element's StartElement
// has been consumed and consumes events through the matching EndElement.
//
// ADR-004 lossless preservation: unknown children (`<p:extLst>`,
// foreign-namespace siblings, future schema additions) are captured into
// the enclosing node's `extension : Array[XmlElement]` via
// `collect_subtree_unknown` rather than discarded.

// --- Comment authors ---

///|
/// Parse a `commentAuthors.xml` part from raw XML bytes.  Root element
/// must be `<p:cmAuthorLst>`.
pub fn CommentAuthorList::parse(
  bytes : FixedArray[Byte],
) -> CommentAuthorList raise CommentsError {
  parse_comment_author_list_xml(bytes_to_string(bytes))
}

///|
fn parse_comment_author_list_xml(
  xml : String,
) -> CommentAuthorList raise CommentsError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  match event {
    StartElement(name, _) => expect_pml(name, "cmAuthorLst")
    _ => raise Malformed("expected <p:cmAuthorLst> root element")
  }
  let authors : Array[CommentAuthor] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.presentation_ns && child.local_name == "cmAuthor" {
          authors.push(parse_comment_author(r, attrs))
        } else {
          extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { authors, extension }
}

///|
fn parse_comment_author(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> CommentAuthor raise CommentsError {
  let id = parse_int_attr(attrs, "id")
  let name = optional_attr(attrs, "name")
  let initials = optional_attr(attrs, "initials")
  let last_idx = parse_int_attr(attrs, "lastIdx")
  let clr_idx = parse_int_attr(attrs, "clrIdx")
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      // <p:cmAuthor> body — the schema defines only <p:extLst> here; we
      // capture everything verbatim per ADR-004.
      StartElement(child, child_attrs) =>
        extension.push(collect_subtree_unknown(r, child, child_attrs))
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, initials, last_idx, clr_idx, extension }
}

// --- Comments ---

///|
/// Parse a `commentsN.xml` part from raw XML bytes. Root element must
/// be `<p:cmLst>`.
pub fn CommentList::parse(
  bytes : FixedArray[Byte],
) -> CommentList raise CommentsError {
  parse_comment_list_xml(bytes_to_string(bytes))
}

///|
fn parse_comment_list_xml(xml : String) -> CommentList raise CommentsError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  match event {
    StartElement(name, _) => expect_pml(name, "cmLst")
    _ => raise Malformed("expected <p:cmLst> root element")
  }
  let comments : Array[Comment] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.presentation_ns && child.local_name == "cm" {
          comments.push(parse_comment(r, attrs))
        } else {
          extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { comments, extension }
}

///|
fn parse_comment(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Comment raise CommentsError {
  let author_id = parse_int_attr(attrs, "authorId")
  let dt = optional_attr_some(attrs, "dt")
  let idx = parse_int_attr(attrs, "idx")
  let mut pos : CommentPos? = None
  let mut text : String = ""
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "pos" => {
              pos = Some(parse_comment_pos(child_attrs))
              skip_subtree(r) // <p:pos> is a leaf
            }
            "text" => text = parse_text_body(r)
            // <p:extLst> and any future <p:cm> siblings.
            _ => extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let p = match pos {
    Some(p) => p
    None => raise Malformed("<p:cm> is missing required <p:pos>")
  }
  { author_id, dt, idx, pos: p, text, extension }
}

///|
fn parse_comment_pos(
  attrs : Array[(@xml.QName, String)],
) -> CommentPos raise CommentsError {
  {
    x: @units.Emu(parse_int64_attr(attrs, "x")),
    y: @units.Emu(parse_int64_attr(attrs, "y")),
  }
}

///|
/// Read the text content of an element whose body is a single text run
/// (no nested elements). Used for `<p:text>`. Concatenates `Text` + `CData`
/// events; aborts on any nested StartElement (out of spec) by raising.
fn parse_text_body(r : @xml.XmlReader) -> String raise CommentsError {
  let mut acc = ""
  while true {
    let ev = next_event(r)
    match ev {
      Text(s) => acc = acc + s
      CData(s) => acc = acc + s
      StartElement(name, _) =>
        raise Malformed(
          "unexpected nested element <" + name.local_name + "> inside <p:text>",
        )
      EndElement(_) => break
    }
  }
  acc
}

// --- shared helpers ---

///|
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise CommentsError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise Malformed("unexpected end of input")
  }
}

///|
fn expect_pml(name : @xml.QName, expected : String) -> Unit raise CommentsError {
  if name.uri != @oxml.presentation_ns || name.local_name != expected {
    raise Malformed(
      "expected <p:" + expected + "> but got <" + name.local_name + ">",
    )
  }
}

///|
fn collect_subtree_unknown(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> @xml.XmlElement raise CommentsError {
  @oxml.collect_subtree(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn skip_subtree(r : @xml.XmlReader) -> Unit raise CommentsError {
  @oxml.skip_subtree(r) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn optional_attr(attrs : Array[(@xml.QName, String)], name : String) -> String {
  @oxml.optional_attr_or(attrs, name, "")
}

///|
/// Like `optional_attr` but distinguishes "attribute absent" from
/// "attribute present and empty". Used for `<p:cm dt="…"/>` which the
/// schema marks optional.
fn optional_attr_some(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String? {
  @oxml.optional_attr(attrs, name)
}

///|
fn parse_int_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Int raise CommentsError {
  let raw = require_attr(attrs, name)
  match @oxml.parse_signed_int(raw) {
    Some(n) => n
    None => raise Malformed("attribute " + name + " is not an integer: " + raw)
  }
}

///|
fn parse_int64_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Int64 raise CommentsError {
  let raw = require_attr(attrs, name)
  match @oxml.parse_signed_int64(raw) {
    Some(n) => n
    None => raise Malformed("attribute " + name + " is not an integer: " + raw)
  }
}

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String raise CommentsError {
  @oxml.require_attr(attrs, name, name) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise CommentsError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
}
