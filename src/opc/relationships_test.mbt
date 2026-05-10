///|
let rels_ns_test : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
fn rels_xml(body : String) -> String {
  "<?xml version=\"1.0\"?>" +
  "<Relationships xmlns=\"" +
  rels_ns_test +
  "\">" +
  body +
  "</Relationships>"
}

// --- rels_path_for ---

///|
test "rels_path_for: package root" {
  assert_eq(@opc.rels_path_for(@opc.package_root), "/_rels/.rels")
}

///|
test "rels_path_for: part" {
  assert_eq(
    @opc.rels_path_for("/ppt/presentation.xml"),
    "/ppt/_rels/presentation.xml.rels",
  )
  assert_eq(
    @opc.rels_path_for("/ppt/slides/slide1.xml"),
    "/ppt/slides/_rels/slide1.xml.rels",
  )
}

// --- resolve_target ---

///|
test "resolve_target: relative inside same dir" {
  assert_eq(
    @opc.resolve_target(
      "/ppt/presentation.xml",
      "slides/slide1.xml",
      @opc.TargetMode::Internal,
    ),
    "/ppt/slides/slide1.xml",
  )
}

///|
test "resolve_target: walks `..`" {
  assert_eq(
    @opc.resolve_target(
      "/ppt/slides/slide1.xml",
      "../media/image1.png",
      @opc.TargetMode::Internal,
    ),
    "/ppt/media/image1.png",
  )
}

///|
test "resolve_target: absolute target unchanged" {
  assert_eq(
    @opc.resolve_target(
      "/ppt/slides/slide1.xml",
      "/docProps/core.xml",
      @opc.TargetMode::Internal,
    ),
    "/docProps/core.xml",
  )
}

///|
test "resolve_target: external target unchanged" {
  assert_eq(
    @opc.resolve_target(
      "/ppt/slides/slide1.xml",
      "https://example.org/x.png",
      @opc.TargetMode::External,
    ),
    "https://example.org/x.png",
  )
}

///|
test "resolve_target: from package root" {
  assert_eq(
    @opc.resolve_target(
      @opc.package_root,
      "ppt/presentation.xml",
      @opc.TargetMode::Internal,
    ),
    "/ppt/presentation.xml",
  )
}

// --- parse / serialize ---

///|
test "parse single Internal relationship" {
  let xml = rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
  )
  let rels = @opc.Relationships::parse(@opc.package_root, @fzip.str_to_u8(xml))
  assert_eq(rels.items.length(), 1)
  let r = rels.items[0]
  assert_eq(r.id, "rId1")
  assert_eq(r.target, "ppt/presentation.xml")
  assert_true(r.target_mode is @opc.TargetMode::Internal)
}

///|
test "parse External TargetMode" {
  let xml = rels_xml(
    "<Relationship Id=\"rId7\" Type=\"http://example/external\" Target=\"https://example.org/x\" TargetMode=\"External\"/>",
  )
  let rels = @opc.Relationships::parse("/foo.xml", @fzip.str_to_u8(xml))
  assert_true(rels.items[0].target_mode is @opc.TargetMode::External)
}

///|
test "parse rejects malformed input" {
  let bad = "<?xml version=\"1.0\"?><Relationships><Relationship/></Relationships>"
  let r1 = try? @opc.Relationships::parse(
    @opc.package_root,
    @fzip.str_to_u8(bad),
  )
  assert_true(r1 is Err(@opc.OpcError::MalformedPackage(_)))
  let bad2 = rels_xml("<Relationship Id=\"rId1\" Type=\"x\"/>") // no Target
  let r2 = try? @opc.Relationships::parse(
    @opc.package_root,
    @fzip.str_to_u8(bad2),
  )
  assert_true(r2 is Err(@opc.OpcError::MalformedPackage(_)))
  let bad3 = rels_xml(
    "<Relationship Id=\"rId1\" Type=\"x\" Target=\"y\" TargetMode=\"Weird\"/>",
  )
  let r3 = try? @opc.Relationships::parse(
    @opc.package_root,
    @fzip.str_to_u8(bad3),
  )
  assert_true(r3 is Err(@opc.OpcError::MalformedPackage(_)))
}

///|
test "serialize -> parse round trip preserves entries" {
  let original = @opc.Relationships::new(@opc.package_root)
    .with_relationship({
      id: "rId1",
      rel_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
      target: "ppt/presentation.xml",
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId2",
      rel_type: "http://example/external",
      target: "https://example.org/x",
      target_mode: External,
    })
  let bytes = original.serialize()
  let reparsed = @opc.Relationships::parse(@opc.package_root, bytes)
  assert_eq(reparsed.items.length(), 2)
  for i in 0..<original.items.length() {
    assert_eq(reparsed.items[i], original.items[i])
  }
}

///|
test "with_relationship rejects duplicate ids" {
  let r1 : @opc.Relationship = {
    id: "rId1",
    rel_type: "x",
    target: "a",
    target_mode: @opc.TargetMode::Internal,
  }
  let r2 : @opc.Relationship = {
    id: "rId1",
    rel_type: "y",
    target: "b",
    target_mode: @opc.TargetMode::Internal,
  }
  let rels = @opc.Relationships::new(@opc.package_root).with_relationship(r1)
  let res = try? rels.with_relationship(r2)
  assert_true(res is Err(@opc.OpcError::MalformedPackage(_)))
}

///|
test "by_id and by_type lookups" {
  let rels = @opc.Relationships::new(@opc.package_root)
    .with_relationship({
      id: "rId1",
      rel_type: "type-a",
      target: "a",
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId2",
      rel_type: "type-b",
      target: "b",
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId3",
      rel_type: "type-a",
      target: "c",
      target_mode: Internal,
    })
  assert_eq(rels.by_id("rId2").unwrap().target, "b")
  assert_true(rels.by_id("missing") is None)
  assert_eq(rels.by_type("type-a").length(), 2)
  assert_eq(rels.by_type("type-b").length(), 1)
  assert_eq(rels.by_type("missing").length(), 0)
}

// --- Package integration ---

///|
let ct_ns_rt : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
fn make_pkg_with_rels(extra : Array[(String, String)]) -> FixedArray[Byte] {
  let entries : Array[(String, FixedArray[Byte])] = []
  let ct_xml = "<?xml version=\"1.0\"?><Types xmlns=\"" +
    ct_ns_rt +
    "\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "</Types>"
  entries.push(("[Content_Types].xml", @fzip.str_to_u8(ct_xml)))
  for kv in extra {
    entries.push((kv.0, @fzip.str_to_u8(kv.1)))
  }
  @fzip.zip_sync(entries)
}

///|
test "Package::relationships_for: package root" {
  let pkg_rels_xml = "<?xml version=\"1.0\"?><Relationships xmlns=\"" +
    rels_ns_test +
    "\"><Relationship Id=\"rId1\" Type=\"http://t1\" Target=\"ppt/presentation.xml\"/></Relationships>"
  let bytes = make_pkg_with_rels([
    ("_rels/.rels", pkg_rels_xml),
    ("ppt/presentation.xml", "<presentation/>"),
  ])
  let pkg = @opc.Package::open(bytes)
  let rels = pkg.relationships_for(@opc.package_root)
  assert_eq(rels.items.length(), 1)
  assert_eq(rels.items[0].id, "rId1")
}

///|
test "Package::relationships_for: missing rels file returns empty" {
  let bytes = make_pkg_with_rels([("ppt/presentation.xml", "<presentation/>")])
  let pkg = @opc.Package::open(bytes)
  let rels = pkg.relationships_for("/ppt/presentation.xml")
  assert_eq(rels.items.length(), 0)
}

///|
test "Package::relationships_for: part-level rels" {
  let part_rels_xml = "<?xml version=\"1.0\"?><Relationships xmlns=\"" +
    rels_ns_test +
    "\"><Relationship Id=\"rId1\" Type=\"http://t/slide\" Target=\"slides/slide1.xml\"/></Relationships>"
  let bytes = make_pkg_with_rels([
    ("ppt/presentation.xml", "<presentation/>"),
    ("ppt/_rels/presentation.xml.rels", part_rels_xml),
    ("ppt/slides/slide1.xml", "<sld/>"),
  ])
  let pkg = @opc.Package::open(bytes)
  let rels = pkg.relationships_for("/ppt/presentation.xml")
  assert_eq(rels.items.length(), 1)
  let target = @opc.resolve_target(
    "/ppt/presentation.xml",
    rels.items[0].target,
    rels.items[0].target_mode,
  )
  assert_eq(target, "/ppt/slides/slide1.xml")
  // Verify the resolved target is in fact a real part.
  assert_true(!(pkg.part_by_name(target) is None))
}
