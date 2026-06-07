// Test fixtures: build minimal valid OPC packages in memory via fzip.

///|
let ct_ns : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
/// A minimal `[Content_Types].xml` that registers `xml` and `rels`
/// extensions and overrides the presentation part.
fn minimal_content_types_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Types xmlns=\"" +
  ct_ns +
  "\">" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
  "</Types>"
}

///|
/// Pack a list of `(zip-name, text)` entries; always inserts a valid
/// `[Content_Types].xml` first unless the caller already supplied one.
fn make_pkg_bytes(entries : Array[(String, String)]) -> FixedArray[Byte] {
  let raw : Array[(String, FixedArray[Byte])] = Array::new(
    capacity=entries.length() + 1,
  )
  let mut has_ct = false
  for kv in entries {
    if kv.0 == "[Content_Types].xml" {
      has_ct = true
    }
    raw.push((kv.0, @fzip.str_to_u8(kv.1)))
  }
  if !has_ct {
    raw.insert(
      0,
      ("[Content_Types].xml", @fzip.str_to_u8(minimal_content_types_xml())),
    )
  }
  @fzip.zip_sync(raw)
}

///|
test "Package::open round-trips a tiny zip" {
  let bytes = make_pkg_bytes([("ppt/presentation.xml", "<presentation/>")])
  let pkg = @opc.Package::open(bytes)
  assert_eq(pkg.parts().length(), 2)
  let p1 = pkg.require_part("/[Content_Types].xml")
  assert_true(p1.text().length() > 0)
  let p2 = pkg.require_part("/ppt/presentation.xml")
  assert_eq(p2.text(), "<presentation/>")
}

///|
test "open populates content_type from [Content_Types].xml" {
  let bytes = make_pkg_bytes([("ppt/presentation.xml", "<presentation/>")])
  let pkg = @opc.Package::open(bytes)
  let p = pkg.require_part("/ppt/presentation.xml")
  assert_eq(
    p.content_type,
    "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml",
  )
}

///|
test "open falls back to Default extension for content type" {
  let bytes = make_pkg_bytes([("ppt/slides/slide1.xml", "<sld/>")])
  let pkg = @opc.Package::open(bytes)
  // No Override for slide1.xml — falls back to Default Extension="xml".
  let p = pkg.require_part("/ppt/slides/slide1.xml")
  assert_eq(p.content_type, "application/xml")
}

///|
test "round trip: open -> to_bytes -> open" {
  let original = make_pkg_bytes([
    ("ppt/presentation.xml", "<presentation/>"),
    ("ppt/slides/slide1.xml", "<sld/>"),
  ])
  let pkg1 = @opc.Package::open(original)
  let repacked = pkg1.to_bytes()
  let pkg2 = @opc.Package::open(repacked)
  assert_eq(pkg2.parts().length(), pkg1.parts().length())
  for p in pkg1.parts() {
    let other = pkg2.require_part(p.name)
    assert_eq(other.bytes.length(), p.bytes.length())
  }
}

///|
test "part_by_name returns None for missing parts" {
  let bytes = make_pkg_bytes([("a.xml", "<a/>")])
  let pkg = @opc.Package::open(bytes)
  assert_true(pkg.part_by_name("/missing") is None)
  assert_true(!(pkg.part_by_name("/a.xml") is None))
}

///|
test "open raises when [Content_Types].xml is missing" {
  let bytes = @fzip.zip_sync([("foo.xml", @fzip.str_to_u8("<foo/>"))])
  try @opc.Package::open(bytes) catch {
    @opc.OpcError::MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
}

///|
test "require_part raises PartNotFound" {
  let pkg = @opc.Package::new()
  try pkg.require_part("/missing") catch {
    @opc.OpcError::PartNotFound(_) => ()
    _ => fail("expected PartNotFound")
  } noraise {
    _ => fail("expected PartNotFound")
  }
}

///|
test "add_part / remove_part" {
  let pkg = @opc.Package::new()
  let p = @opc.Part::new("/a.xml", "application/xml", @fzip.str_to_u8("<a/>"))
  pkg.add_part(p)
  assert_eq(pkg.parts().length(), 1)
  let removed = pkg.remove_part("/a.xml")
  assert_true(removed)
  assert_eq(pkg.parts().length(), 0)
  assert_true(!pkg.remove_part("/a.xml"))
}

///|
test "add_part rejects duplicate names" {
  let pkg = @opc.Package::new()
  let p1 = @opc.Part::new("/x.xml", "", @fzip.str_to_u8("<x/>"))
  let p2 = @opc.Part::new("/x.xml", "", @fzip.str_to_u8("<x2/>"))
  pkg.add_part(p1)
  try pkg.add_part(p2) catch {
    @opc.OpcError::MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
}

///|
test "Part::new validates names" {
  let bytes = @fzip.str_to_u8("x")
  for bad in ["", "foo.xml", "/foo/", "/a//b.xml"] {
    try @opc.Part::new(bad, "", bytes) catch {
      @opc.OpcError::MalformedPackage(_) => ()
      _ => fail("expected MalformedPackage")
    } noraise {
      _ => fail("expected MalformedPackage")
    }
  }
}

///|
test "name conversion helpers are inverses" {
  let zip = "ppt/slides/slide1.xml"
  let opc = @opc.zip_name_to_opc(zip)
  assert_eq(opc, "/ppt/slides/slide1.xml")
  assert_eq(@opc.opc_name_to_zip(opc), zip)
}

///|
test "open propagates fzip failures as ZipFailure" {
  let bytes : FixedArray[Byte] = FixedArray::make(8, b'\xFF')
  try @opc.Package::open(bytes) catch {
    @opc.OpcError::ZipFailure(_, _) => ()
    _ => fail("expected ZipFailure")
  } noraise {
    _ => fail("expected ZipFailure")
  }
}

///|
test "regenerate_content_types_part replaces in-place" {
  let pkg = @opc.Package::open(make_pkg_bytes([("a.xml", "<a/>")]))
  let new_ct = @opc.ContentTypes::new()
    .with_default("xml", "application/xml")
    .with_override("/a.xml", "application/custom+xml")
  pkg.set_content_types(new_ct)
  pkg.regenerate_content_types_part()
  // Round trip and verify the new content_type is resolved on reopen.
  let pkg2 = @opc.Package::open(pkg.to_bytes())
  let p = pkg2.require_part("/a.xml")
  assert_eq(p.content_type, "application/custom+xml")
}
