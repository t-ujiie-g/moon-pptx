// Build a tiny in-memory ZIP with @fzip and use it as a Package fixture.

///|
fn make_pkg_bytes(entries : Array[(String, String)]) -> FixedArray[Byte] {
  let raw : Array[(String, FixedArray[Byte])] = Array::new(
    capacity=entries.length(),
  )
  for kv in entries {
    raw.push((kv.0, @fzip.str_to_u8(kv.1)))
  }
  @fzip.zip_sync(raw)
}

///|
test "Package::open round-trips a tiny zip" {
  let bytes = make_pkg_bytes([
    ("[Content_Types].xml", "<Types/>"),
    ("ppt/presentation.xml", "<presentation/>"),
  ])
  let pkg = @opc.Package::open(bytes)
  assert_eq(pkg.parts().length(), 2)
  // OPC names always start with `/`.
  let p1 = pkg.require_part("/[Content_Types].xml")
  assert_eq(p1.text(), "<Types/>")
  let p2 = pkg.require_part("/ppt/presentation.xml")
  assert_eq(p2.text(), "<presentation/>")
}

///|
test "round trip: open -> to_bytes -> open" {
  let original = make_pkg_bytes([
    ("[Content_Types].xml", "<Types/>"),
    ("ppt/presentation.xml", "<presentation/>"),
    ("ppt/slides/slide1.xml", "<sld/>"),
  ])
  let pkg1 = @opc.Package::open(original)
  let repacked = pkg1.to_bytes()
  let pkg2 = @opc.Package::open(repacked)
  assert_eq(pkg2.parts().length(), pkg1.parts().length())
  for p in pkg1.parts() {
    let other = pkg2.require_part(p.name)
    assert_eq(other.text(), p.text())
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
test "require_part raises PartNotFound" {
  let pkg = @opc.Package::new()
  let r = try? pkg.require_part("/missing")
  assert_true(r is Err(@opc.OpcError::PartNotFound(_)))
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
  // remove again is a no-op.
  assert_true(!pkg.remove_part("/a.xml"))
}

///|
test "add_part rejects duplicate names" {
  let pkg = @opc.Package::new()
  let p1 = @opc.Part::new("/x.xml", "", @fzip.str_to_u8("<x/>"))
  let p2 = @opc.Part::new("/x.xml", "", @fzip.str_to_u8("<x2/>"))
  pkg.add_part(p1)
  let r = try? pkg.add_part(p2)
  assert_true(r is Err(@opc.OpcError::MalformedPackage(_)))
}

///|
test "Part::new validates names" {
  let bytes = @fzip.str_to_u8("x")
  // empty
  let r1 = try? @opc.Part::new("", "", bytes)
  assert_true(r1 is Err(@opc.OpcError::MalformedPackage(_)))
  // missing leading slash
  let r2 = try? @opc.Part::new("foo.xml", "", bytes)
  assert_true(r2 is Err(@opc.OpcError::MalformedPackage(_)))
  // trailing slash
  let r3 = try? @opc.Part::new("/foo/", "", bytes)
  assert_true(r3 is Err(@opc.OpcError::MalformedPackage(_)))
  // empty segment
  let r4 = try? @opc.Part::new("/a//b.xml", "", bytes)
  assert_true(r4 is Err(@opc.OpcError::MalformedPackage(_)))
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
  // Random non-zip bytes — fzip should fail and we wrap it.
  let bytes : FixedArray[Byte] = FixedArray::make(8, b'\xFF')
  let r = try? @opc.Package::open(bytes)
  assert_true(r is Err(@opc.OpcError::ZipFailure(_, _)))
}
