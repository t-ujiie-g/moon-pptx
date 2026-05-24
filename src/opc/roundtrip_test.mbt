// End-to-end OPC round trip: build a minimal but realistic package
// shaped like a real `.pptx`, exercise the full open → mutate → save →
// reopen path, and assert that parts and relationships survive.
//
// The fixture is small enough to construct in-memory but covers every OPC
// concept we expose (Default/Override content types, package-level rels,
// part-level rels with relative + `..`-walking targets).

///|
let ct_ns_e2e : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
let rels_ns_e2e : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
let rt_office_doc : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
let rt_slide : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"

///|
let rt_image : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

///|
fn fixture_content_types() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Types xmlns=\"" +
  ct_ns_e2e +
  "\">" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
  "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
  "</Types>"
}

///|
fn fixture_pkg_rels() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"" +
  rels_ns_e2e +
  "\">" +
  "<Relationship Id=\"rId1\" Type=\"" +
  rt_office_doc +
  "\" Target=\"ppt/presentation.xml\"/>" +
  "</Relationships>"
}

///|
fn fixture_presentation_rels() -> String {
  // rId1: slide (relative, same dir) → /ppt/slides/slide1.xml
  // rId2: image (uses `..` to go up to /ppt/media/) — exercises path walk
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"" +
  rels_ns_e2e +
  "\">" +
  "<Relationship Id=\"rId1\" Type=\"" +
  rt_slide +
  "\" Target=\"slides/slide1.xml\"/>" +
  "<Relationship Id=\"rId2\" Type=\"" +
  rt_image +
  "\" Target=\"media/image1.png\"/>" +
  "</Relationships>"
}

///|
fn build_fixture() -> FixedArray[Byte] {
  let entries : Array[(String, FixedArray[Byte])] = [
    ("[Content_Types].xml", @fzip.str_to_u8(fixture_content_types())),
    ("_rels/.rels", @fzip.str_to_u8(fixture_pkg_rels())),
    ("ppt/presentation.xml", @fzip.str_to_u8("<p:presentation xmlns:p=\"x\"/>")),
    (
      "ppt/_rels/presentation.xml.rels",
      @fzip.str_to_u8(fixture_presentation_rels()),
    ),
    ("ppt/slides/slide1.xml", @fzip.str_to_u8("<p:sld xmlns:p=\"x\"/>")),
    // pretend PNG payload — the OPC layer doesn't care about validity
    ("ppt/media/image1.png", @fzip.str_to_u8("FAKEPNG")),
  ]
  @fzip.zip_sync(entries)
}

///|
test "fixture: opens with all parts present" {
  let pkg = @opc.Package::open(build_fixture())
  assert_eq(pkg.parts().length(), 6)
  let names = [
    "/[Content_Types].xml", "/_rels/.rels", "/ppt/presentation.xml", "/ppt/_rels/presentation.xml.rels",
    "/ppt/slides/slide1.xml", "/ppt/media/image1.png",
  ]
  for n in names {
    let _ = pkg.require_part(n)
  }
}

///|
test "fixture: content types resolve correctly per part" {
  let pkg = @opc.Package::open(build_fixture())
  // Override on the presentation part
  assert_eq(
    pkg.require_part("/ppt/presentation.xml").content_type,
    "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml",
  )
  // Override on the slide part
  assert_eq(
    pkg.require_part("/ppt/slides/slide1.xml").content_type,
    "application/vnd.openxmlformats-officedocument.presentationml.slide+xml",
  )
  // Default by extension `.png`
  assert_eq(pkg.require_part("/ppt/media/image1.png").content_type, "image/png")
  // Default by extension `.rels`
  assert_eq(
    pkg.require_part("/_rels/.rels").content_type,
    "application/vnd.openxmlformats-package.relationships+xml",
  )
}

///|
test "fixture: package-level rels point at the presentation" {
  let pkg = @opc.Package::open(build_fixture())
  let rels = pkg.relationships_for(@opc.package_root)
  assert_eq(rels.items.length(), 1)
  let r = rels.by_type(rt_office_doc)
  assert_eq(r.length(), 1)
  assert_eq(
    @opc.resolve_target(@opc.package_root, r[0].target, r[0].target_mode),
    "/ppt/presentation.xml",
  )
}

///|
test "fixture: presentation rels resolve to real parts (incl. `..` walk)" {
  let pkg = @opc.Package::open(build_fixture())
  let rels = pkg.relationships_for("/ppt/presentation.xml")
  assert_eq(rels.items.length(), 2)
  // rId1 → slide
  let slide_rel = rels.by_id("rId1").unwrap()
  let slide_path = @opc.resolve_target(
    "/ppt/presentation.xml",
    slide_rel.target,
    slide_rel.target_mode,
  )
  assert_eq(slide_path, "/ppt/slides/slide1.xml")
  assert_true(!(pkg.part_by_name(slide_path) is None))
  // rId2 → image (relative target, no `..` here but exercises lookup)
  let img_rel = rels.by_id("rId2").unwrap()
  let img_path = @opc.resolve_target(
    "/ppt/presentation.xml",
    img_rel.target,
    img_rel.target_mode,
  )
  assert_eq(img_path, "/ppt/media/image1.png")
  assert_true(!(pkg.part_by_name(img_path) is None))
}

///|
test "round trip: open -> to_bytes -> open preserves shape" {
  let pkg1 = @opc.Package::open(build_fixture())
  let pkg2 = @opc.Package::open(pkg1.to_bytes())
  assert_eq(pkg2.parts().length(), pkg1.parts().length())
  for p in pkg1.parts() {
    let other = pkg2.require_part(p.name)
    assert_eq(other.content_type, p.content_type)
    assert_eq(other.bytes.length(), p.bytes.length())
  }
  // Rels survive too.
  let r1 = pkg1.relationships_for("/ppt/presentation.xml")
  let r2 = pkg2.relationships_for("/ppt/presentation.xml")
  assert_eq(r2.items.length(), r1.items.length())
}

///|
test "mutate: add a slide part + register override + save + reopen" {
  let pkg = @opc.Package::open(build_fixture())
  // Add a new slide part.
  let new_slide = @opc.Part::new(
    "/ppt/slides/slide2.xml",
    "",
    @fzip.str_to_u8("<p:sld xmlns:p=\"x\"/>"),
  )
  pkg.add_part(new_slide)
  // Register the Override for it.
  let new_ct = pkg
    .content_types()
    .with_override(
      "/ppt/slides/slide2.xml", "application/vnd.openxmlformats-officedocument.presentationml.slide+xml",
    )
  pkg.set_content_types(new_ct)
  pkg.regenerate_content_types_part()
  // Save and reopen.
  let pkg2 = @opc.Package::open(pkg.to_bytes())
  let p = pkg2.require_part("/ppt/slides/slide2.xml")
  assert_eq(
    p.content_type,
    "application/vnd.openxmlformats-officedocument.presentationml.slide+xml",
  )
}

///|
test "mutate: replace a part's bytes survives round trip" {
  let pkg = @opc.Package::open(build_fixture())
  // Replace the slide content.
  let _ = pkg.remove_part("/ppt/slides/slide1.xml")
  let updated = @opc.Part::new(
    "/ppt/slides/slide1.xml",
    "",
    @fzip.str_to_u8("<p:sld xmlns:p=\"x\"><edited/></p:sld>"),
  )
  pkg.add_part(updated)
  let pkg2 = @opc.Package::open(pkg.to_bytes())
  let p = pkg2.require_part("/ppt/slides/slide1.xml")
  let s = p.text()
  assert_true(s.contains("<edited/>"))
}
