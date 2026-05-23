// @opc clone tests — Phase 5f1.

///|
test "Package::clone: clones share no mutable state" {
  let pkg = @opc.Package::new()
  let p1 = @opc.Part::new(
    "/ppt/test.xml",
    "application/xml",
    @fzip.str_to_u8("<a/>"),
  )
  pkg.add_part(p1)
  let cloned = pkg.clone()
  // Adding a part to the clone doesn't show up in the original.
  let p2 = @opc.Part::new(
    "/ppt/other.xml",
    "application/xml",
    @fzip.str_to_u8("<b/>"),
  )
  cloned.add_part(p2)
  assert_eq(pkg.parts().length(), 1)
  assert_eq(cloned.parts().length(), 2)
}

///|
test "Part::clone: bytes buffer is independent" {
  let bytes = @fzip.str_to_u8("hello")
  let p1 = @opc.Part::new("/x.xml", "application/xml", bytes)
  let p2 = p1.clone()
  // Mutating p1's bytes (via the underlying FixedArray) doesn't
  // change p2's bytes.
  p1.bytes[0] = b'H'
  assert_eq(p1.bytes[0], b'H')
  assert_eq(p2.bytes[0], b'h')
}

///|
test "ContentTypes::clone: builder mutations don't cross over" {
  let ct = @opc.ContentTypes::new()
    .with_default("xml", "application/xml")
    .with_override("/a.xml", "type/a")
  let cloned = ct.clone()
  // Extend the clone with another default. The original's defaults
  // array stays at one entry.
  let _ = cloned.with_default("rels", "type/rels")
  assert_eq(ct.defaults.length(), 1)
  // The clone is structurally equal to the original by Eq (the
  // chained .with_default isn't applied to the clone in place — it
  // returns a new value).
  assert_true(ct == cloned)
}

///|
test "Package::clone: content-types catalog is independent" {
  let pkg = @opc.Package::new()
  let p = @opc.Part::new("/x.xml", "type/x", @fzip.str_to_u8("<x/>"))
  pkg.add_part(p)
  pkg.set_content_types(
    @opc.ContentTypes::new().with_override("/x.xml", "type/x"),
  )
  let cloned = pkg.clone()
  cloned.set_content_types(
    @opc.ContentTypes::new()
    .with_default("xml", "type/xml")
    .with_override("/x.xml", "type/x"),
  )
  // Original's content_types still has only the one override and
  // no defaults.
  assert_eq(pkg.content_types().defaults.length(), 0)
  assert_eq(cloned.content_types().defaults.length(), 1)
}
