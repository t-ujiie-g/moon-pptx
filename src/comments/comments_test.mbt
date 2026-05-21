// Comments parser tests (Phase 3g2 / 3g3).

///|
let pml_ns : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
fn fixture_bytes(s : String) -> FixedArray[Byte] {
  let buf : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp)
    } else if cp < 0x800 {
      buf.push(0xC0 | (cp >> 6))
      buf.push(0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      buf.push(0xE0 | (cp >> 12))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    } else {
      buf.push(0xF0 | (cp >> 18))
      buf.push(0x80 | ((cp >> 12) & 0x3F))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    }
  }
  let bytes = FixedArray::make(buf.length(), b'\x00')
  let mut i = 0
  while i < buf.length() {
    bytes[i] = buf[i].to_byte()
    i = i + 1
  }
  bytes
}

// --- commentAuthors.xml ---

///|
fn typical_authors() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"Alice\" initials=\"A\" lastIdx=\"3\" clrIdx=\"0\"/>" +
    "<p:cmAuthor id=\"1\" name=\"Bob\" initials=\"BB\" lastIdx=\"1\" clrIdx=\"1\">" +
    "<p:extLst><p:ext uri=\"{ABC}\"/></p:extLst>" +
    "</p:cmAuthor>" +
    "</p:cmAuthorLst>"
  fixture_bytes(xml)
}

///|
test "CommentAuthorList::parse: count + first author fields" {
  let list = @comments.CommentAuthorList::parse(typical_authors())
  assert_eq(list.authors.length(), 2)
  let alice = list.authors[0]
  assert_eq(alice.id, 0)
  assert_eq(alice.name, "Alice")
  assert_eq(alice.initials, "A")
  assert_eq(alice.last_idx, 3)
  assert_eq(alice.clr_idx, 0)
  assert_eq(alice.extension.length(), 0)
}

///|
test "CommentAuthorList::parse: per-author extLst is preserved" {
  let list = @comments.CommentAuthorList::parse(typical_authors())
  let bob = list.authors[1]
  assert_eq(bob.id, 1)
  assert_eq(bob.name, "Bob")
  assert_eq(bob.initials, "BB")
  assert_eq(bob.extension.length(), 1)
  assert_eq(bob.extension[0].name.local_name, "extLst")
}

///|
test "CommentAuthorList::parse: empty list" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" + pml_ns + "\"/>"
  let list = @comments.CommentAuthorList::parse(fixture_bytes(xml))
  assert_eq(list.authors.length(), 0)
  assert_eq(list.extension.length(), 0)
}

///|
test "CommentAuthorList::parse: top-level extLst rides on list extension" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"A\" initials=\"A\" lastIdx=\"0\" clrIdx=\"0\"/>" +
    "<p:extLst><p:ext uri=\"{X}\"/></p:extLst>" +
    "</p:cmAuthorLst>"
  let list = @comments.CommentAuthorList::parse(fixture_bytes(xml))
  assert_eq(list.authors.length(), 1)
  assert_eq(list.extension.length(), 1)
  assert_eq(list.extension[0].name.local_name, "extLst")
}

///|
test "CommentAuthorList::parse: missing required attribute raises Malformed" {
  // `clrIdx` is required by the schema; omit it and confirm we raise.
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"A\" initials=\"A\" lastIdx=\"0\"/>" +
    "</p:cmAuthorLst>"
  let err = try? @comments.CommentAuthorList::parse(fixture_bytes(xml))
  assert_true(err is Err(@comments.CommentsError::Malformed(_)))
}

///|
test "CommentAuthorList::parse: wrong root element raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" + pml_ns + "\"/>"
  let err = try? @comments.CommentAuthorList::parse(fixture_bytes(xml))
  assert_true(err is Err(@comments.CommentsError::Malformed(_)))
}

// --- commentsN.xml ---

///|
fn typical_comments() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" dt=\"2026-05-21T10:30:00\" idx=\"1\">" +
    "<p:pos x=\"1828800\" y=\"914400\"/>" +
    "<p:text>Looks good to me.</p:text>" +
    "</p:cm>" +
    "<p:cm authorId=\"1\" idx=\"2\">" +
    // No dt — older PowerPoint versions omitted this.
    "<p:pos x=\"3657600\" y=\"2743200\"/>" +
    "<p:text>Needs a citation.</p:text>" +
    "<p:extLst><p:ext uri=\"{XYZ}\"/></p:extLst>" +
    "</p:cm>" +
    "</p:cmLst>"
  fixture_bytes(xml)
}

///|
test "CommentList::parse: count + first comment fields" {
  let list = @comments.CommentList::parse(typical_comments())
  assert_eq(list.comments.length(), 2)
  let first = list.comments[0]
  assert_eq(first.author_id, 0)
  assert_eq(first.dt.unwrap(), "2026-05-21T10:30:00")
  assert_eq(first.idx, 1)
  assert_eq(first.pos.x, @units.Emu(1828800L))
  assert_eq(first.pos.y, @units.Emu(914400L))
  assert_eq(first.text, "Looks good to me.")
  assert_eq(first.extension.length(), 0)
}

///|
test "CommentList::parse: dt is optional" {
  let list = @comments.CommentList::parse(typical_comments())
  let second = list.comments[1]
  assert_eq(second.author_id, 1)
  assert_true(second.dt is None)
  assert_eq(second.idx, 2)
  assert_eq(second.text, "Needs a citation.")
}

///|
test "CommentList::parse: per-comment extLst is preserved" {
  let list = @comments.CommentList::parse(typical_comments())
  let second = list.comments[1]
  assert_eq(second.extension.length(), 1)
  assert_eq(second.extension[0].name.local_name, "extLst")
}

///|
test "CommentList::parse: empty list" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" + pml_ns + "\"/>"
  let list = @comments.CommentList::parse(fixture_bytes(xml))
  assert_eq(list.comments.length(), 0)
  assert_eq(list.extension.length(), 0)
}

///|
test "CommentList::parse: missing <p:pos> raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\"><p:text>oops</p:text></p:cm>" +
    "</p:cmLst>"
  let err = try? @comments.CommentList::parse(fixture_bytes(xml))
  assert_true(err is Err(@comments.CommentsError::Malformed(_)))
}

///|
test "CommentList::parse: nested element inside <p:text> raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text><p:foo/></p:text>" +
    "</p:cm></p:cmLst>"
  let err = try? @comments.CommentList::parse(fixture_bytes(xml))
  assert_true(err is Err(@comments.CommentsError::Malformed(_)))
}

///|
test "CommentList::parse: unknown child of <p:cm> is preserved" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text>hi</p:text>" +
    "<p:futureSibling foo=\"bar\"/>" +
    "</p:cm></p:cmLst>"
  let list = @comments.CommentList::parse(fixture_bytes(xml))
  let c = list.comments[0]
  assert_eq(c.extension.length(), 1)
  assert_eq(c.extension[0].name.local_name, "futureSibling")
}

///|
test "CommentList::parse: wrong root element raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" + pml_ns + "\"/>"
  let err = try? @comments.CommentList::parse(fixture_bytes(xml))
  assert_true(err is Err(@comments.CommentsError::Malformed(_)))
}

///|
test "CommentList::parse: text with entity references decodes" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text>a &amp; b &lt; c</p:text>" +
    "</p:cm></p:cmLst>"
  let list = @comments.CommentList::parse(fixture_bytes(xml))
  assert_eq(list.comments[0].text, "a & b < c")
}
