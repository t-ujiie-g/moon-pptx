// Comments writer round-trip tests (Phase 4a).
//
// The Phase 4 floor is: parse → serialize → parse → Eq. Every test
// here builds a value (often via `::parse` of a hand-written fixture),
// serialises it, re-parses, and asserts the second parse equals the
// first. Combined with the parser-side tests in `comments_test.mbt`,
// this verifies that the writer is the inverse of the parser on the
// space of values the parser actually produces.

// --- CommentAuthorList ---

///|
test "CommentAuthorList::serialize: round-trips a 2-author list" {
  let list_in = @comments.CommentAuthorList::parse(typical_authors())
  let bytes_out = list_in.serialize()
  let list_out = @comments.CommentAuthorList::parse(bytes_out)
  assert_true(list_in == list_out)
}

///|
test "CommentAuthorList::serialize: round-trips empty list" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" + pml_ns + "\"/>"
  let list_in = @comments.CommentAuthorList::parse(fixture_bytes(xml))
  let list_out = @comments.CommentAuthorList::parse(list_in.serialize())
  assert_true(list_in == list_out)
}

///|
test "CommentAuthorList::serialize: preserves per-author extLst" {
  let list_in = @comments.CommentAuthorList::parse(typical_authors())
  // Bob (authors[1]) carries an <p:extLst> child captured into
  // CommentAuthor.extension. Round-trip must keep it.
  let list_out = @comments.CommentAuthorList::parse(list_in.serialize())
  assert_eq(list_out.authors[1].extension.length(), 1)
  assert_eq(list_out.authors[1].extension[0].name.local_name, "extLst")
}

///|
test "CommentAuthorList::serialize: preserves list-level extLst" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"A\" initials=\"A\" lastIdx=\"0\" clrIdx=\"0\"/>" +
    "<p:extLst><p:ext uri=\"{X}\"/></p:extLst>" +
    "</p:cmAuthorLst>"
  let list_in = @comments.CommentAuthorList::parse(fixture_bytes(xml))
  let list_out = @comments.CommentAuthorList::parse(list_in.serialize())
  assert_true(list_in == list_out)
  assert_eq(list_out.extension.length(), 1)
  assert_eq(list_out.extension[0].name.local_name, "extLst")
}

// --- CommentList ---

///|
test "CommentList::serialize: round-trips a 2-comment list" {
  let list_in = @comments.CommentList::parse(typical_comments())
  let list_out = @comments.CommentList::parse(list_in.serialize())
  assert_true(list_in == list_out)
}

///|
test "CommentList::serialize: preserves the optional dt attribute" {
  let list_in = @comments.CommentList::parse(typical_comments())
  let list_out = @comments.CommentList::parse(list_in.serialize())
  // Comment 0 has dt, comment 1 doesn't — both must survive intact.
  assert_eq(list_out.comments[0].dt.unwrap(), "2026-05-21T10:30:00")
  assert_true(list_out.comments[1].dt is None)
}

///|
test "CommentList::serialize: preserves per-comment extLst" {
  let list_in = @comments.CommentList::parse(typical_comments())
  let list_out = @comments.CommentList::parse(list_in.serialize())
  // Comment 1 carries an extLst sibling captured into its extension.
  assert_eq(list_out.comments[1].extension.length(), 1)
  assert_eq(list_out.comments[1].extension[0].name.local_name, "extLst")
}

///|
test "CommentList::serialize: escapes text with XML metacharacters" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text>a &amp; b &lt; c</p:text>" +
    "</p:cm></p:cmLst>"
  let list_in = @comments.CommentList::parse(fixture_bytes(xml))
  let list_out = @comments.CommentList::parse(list_in.serialize())
  // After round-trip the text is still the decoded "a & b < c".
  assert_eq(list_out.comments[0].text, "a & b < c")
}

///|
test "CommentList::serialize: preserves pos coordinates verbatim" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"123456789\" y=\"-987\"/>" +
    "<p:text>x</p:text>" +
    "</p:cm></p:cmLst>"
  let list_in = @comments.CommentList::parse(fixture_bytes(xml))
  let list_out = @comments.CommentList::parse(list_in.serialize())
  assert_eq(list_out.comments[0].pos.x, @units.Emu(123456789L))
  assert_eq(list_out.comments[0].pos.y, @units.Emu(-987L))
}

///|
test "CommentList::serialize: round-trips empty list" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" + pml_ns + "\"/>"
  let list_in = @comments.CommentList::parse(fixture_bytes(xml))
  let list_out = @comments.CommentList::parse(list_in.serialize())
  assert_true(list_in == list_out)
}

///|
test "CommentList::serialize: round-trips unknown <p:cm> child via extension" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text>hi</p:text>" +
    "<p:futureSibling foo=\"bar\"/>" +
    "</p:cm></p:cmLst>"
  let list_in = @comments.CommentList::parse(fixture_bytes(xml))
  let list_out = @comments.CommentList::parse(list_in.serialize())
  assert_eq(list_out.comments[0].extension.length(), 1)
  assert_eq(list_out.comments[0].extension[0].name.local_name, "futureSibling")
  assert_true(list_in == list_out)
}
