// Comments XML writers — `commentAuthors.xml` and `commentsN.xml`.
//
// Mirrors the parsers in `parser.mbt`: each
// `CommentAuthorList::serialize` / `CommentList::serialize` produces a
// byte stream that, when parsed back through `::parse`, yields a value
// equal to the original (round-trip equality is the writer floor).
//
// Lossless preservation per ADR-004: every node's `extension`
// `Array[XmlElement]` is replayed verbatim via
// `@oxml.write_xml_element`, so unknown children survive the
// read → write cycle.

///|
/// Serialise a `CommentAuthorList` back to `commentAuthors.xml` bytes.
pub fn CommentAuthorList::serialize(
  self : CommentAuthorList,
) -> FixedArray[Byte] raise CommentsError {
  let xml = serialize_author_list_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_author_list_xml(
  list : CommentAuthorList,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cmAuthorLst"))
  w.namespace_attr("p", @oxml.presentation_ns)
  for author in list.authors {
    write_comment_author(w, ctx, author)
  }
  for ext in list.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
  w.to_string()
}

///|
fn write_comment_author(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  a : CommentAuthor,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cmAuthor"))
  w.attribute(@xml.QName::unqualified("id"), a.id.to_string())
  w.attribute(@xml.QName::unqualified("name"), a.name)
  w.attribute(@xml.QName::unqualified("initials"), a.initials)
  w.attribute(@xml.QName::unqualified("lastIdx"), a.last_idx.to_string())
  w.attribute(@xml.QName::unqualified("clrIdx"), a.clr_idx.to_string())
  for ext in a.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

// --- Comments ---

///|
/// Serialise a `CommentList` back to `commentsN.xml` bytes.
pub fn CommentList::serialize(
  self : CommentList,
) -> FixedArray[Byte] raise CommentsError {
  let xml = serialize_comment_list_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_comment_list_xml(list : CommentList) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cmLst"))
  w.namespace_attr("p", @oxml.presentation_ns)
  for cm in list.comments {
    write_comment(w, ctx, cm)
  }
  for ext in list.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
  w.to_string()
}

///|
fn write_comment(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  c : Comment,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cm"))
  w.attribute(@xml.QName::unqualified("authorId"), c.author_id.to_string())
  // `dt` is optional per schema; only emit when present.
  match c.dt {
    Some(s) => w.attribute(@xml.QName::unqualified("dt"), s)
    None => ()
  }
  w.attribute(@xml.QName::unqualified("idx"), c.idx.to_string())
  // <p:pos x y> — required leaf.
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "pos"))
  let @units.Emu(x) = c.pos.x
  let @units.Emu(y) = c.pos.y
  w.attribute(@xml.QName::unqualified("x"), x.to_string())
  w.attribute(@xml.QName::unqualified("y"), y.to_string())
  w.end_element()
  // <p:text>…</p:text> — required text body.
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "text"))
  w.text(c.text)
  w.end_element()
  // Extension siblings (e.g. <p:extLst>) — round-trip verbatim.
  for ext in c.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
