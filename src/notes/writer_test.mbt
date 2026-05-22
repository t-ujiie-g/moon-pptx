// NotesSlide writer round-trip tests (Phase 4f).

///|
fn roundtrip_notes(bytes : FixedArray[Byte]) -> @notes.NotesSlide raise {
  let first = @notes.NotesSlide::parse(bytes)
  @notes.NotesSlide::parse(first.serialize())
}

///|
test "NotesSlide::serialize: round-trips the typical notes slide" {
  let n0 = @notes.NotesSlide::parse(typical_notes())
  let n1 = roundtrip_notes(typical_notes())
  assert_true(n0 == n1)
}

///|
test "NotesSlide::serialize: body placeholder text preserved" {
  let n1 = roundtrip_notes(typical_notes())
  match n1.shapes[1] {
    AutoShape(s) =>
      assert_eq(s.text_body.unwrap().plain_text(), "Speaker notes here.")
    _ => fail("expected AutoShape with body")
  }
}

///|
test "NotesSlide::serialize: root element is <p:notes> (not <p:sld>)" {
  // Sanity check on the serialised bytes: the root local-name must be
  // "notes". We re-parse via `Slide::parse_with_root` with "notes" and
  // succeed; with "sld" it should raise.
  let n = @notes.NotesSlide::parse(typical_notes())
  let bytes = n.serialize()
  // Succeeds for "notes" root.
  let _ = @slide.Slide::parse_with_root(bytes, "notes")
  // Fails for "sld" root since the bytes start with <p:notes>.
  let r = try? @slide.Slide::parse(bytes)
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}
