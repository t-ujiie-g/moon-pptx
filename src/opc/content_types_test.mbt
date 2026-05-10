///|
let ct_ns_test : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
fn ct_xml(body : String) -> String {
  "<?xml version=\"1.0\"?>" +
  "<Types xmlns=\"" +
  ct_ns_test +
  "\">" +
  body +
  "</Types>"
}

///|
test "parse simple Default + Override" {
  let xml = ct_xml(
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
    "<Override PartName=\"/ppt/p.xml\" ContentType=\"application/special+xml\"/>",
  )
  let ct = @opc.ContentTypes::parse(@fzip.str_to_u8(xml))
  assert_eq(ct.defaults.length(), 2)
  assert_eq(ct.overrides.length(), 1)
}

///|
test "resolve: Override wins over Default" {
  let ct = @opc.ContentTypes::new()
    .with_default("xml", "application/xml")
    .with_override("/ppt/p.xml", "application/special+xml")
  assert_eq(ct.resolve("/ppt/p.xml").unwrap(), "application/special+xml")
  assert_eq(ct.resolve("/ppt/q.xml").unwrap(), "application/xml")
}

///|
test "resolve: extension lookup is case-insensitive" {
  let ct = @opc.ContentTypes::new().with_default("XML", "application/xml")
  assert_eq(ct.resolve("/foo.xml").unwrap(), "application/xml")
  assert_eq(ct.resolve("/foo.XML").unwrap(), "application/xml")
  assert_eq(ct.resolve("/foo.Xml").unwrap(), "application/xml")
}

///|
test "resolve: unknown extension returns None" {
  let ct = @opc.ContentTypes::new().with_default("xml", "application/xml")
  assert_true(ct.resolve("/foo.bin") is None)
  assert_true(ct.resolve("/foo") is None) // no extension
}

///|
test "parse rejects elements outside the content-types namespace" {
  let xml = "<?xml version=\"1.0\"?><Types><Default Extension=\"xml\" ContentType=\"x\"/></Types>"
  let r = try? @opc.ContentTypes::parse(@fzip.str_to_u8(xml))
  assert_true(r is Err(@opc.OpcError::MalformedPackage(_)))
}

///|
test "parse rejects missing required attribute" {
  let xml = ct_xml("<Default Extension=\"xml\"/>")
  let r = try? @opc.ContentTypes::parse(@fzip.str_to_u8(xml))
  assert_true(r is Err(@opc.OpcError::MalformedPackage(_)))
}

///|
test "serialize -> parse round trip preserves entries" {
  let original = @opc.ContentTypes::new()
    .with_default(
      "rels", "application/vnd.openxmlformats-package.relationships+xml",
    )
    .with_default("xml", "application/xml")
    .with_override(
      "/ppt/presentation.xml", "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml",
    )
  let bytes = original.serialize()
  let reparsed = @opc.ContentTypes::parse(bytes)
  assert_eq(reparsed.defaults.length(), original.defaults.length())
  assert_eq(reparsed.overrides.length(), original.overrides.length())
  for i in 0..<original.defaults.length() {
    assert_eq(reparsed.defaults[i], original.defaults[i])
  }
  for i in 0..<original.overrides.length() {
    assert_eq(reparsed.overrides[i], original.overrides[i])
  }
}

///|
test "with_default and with_override are immutable" {
  let base = @opc.ContentTypes::new()
  let plus_default = base.with_default("xml", "application/xml")
  // base unchanged
  assert_eq(base.defaults.length(), 0)
  assert_eq(plus_default.defaults.length(), 1)
  let plus_both = plus_default.with_override("/p.xml", "x/y")
  assert_eq(plus_default.overrides.length(), 0)
  assert_eq(plus_both.overrides.length(), 1)
}
