// Tests for typed document core properties (`docProps/core.xml`, v0.6 F2).

///|
test "core_properties: blank deck reads the template defaults" {
  let prs = @presentation.Presentation::new()
  let cp = prs.core_properties()
  assert_eq(cp.creator.unwrap(), "moon-pptx")
  assert_eq(cp.last_modified_by.unwrap(), "moon-pptx")
  assert_eq(cp.revision.unwrap(), "1")
  assert_eq(cp.title.unwrap(), "") // blank emits an empty <dc:title>
  assert_true(cp.subject is None)
}

///|
test "core_properties: set then read round-trips every field" {
  let prs = @presentation.Presentation::new()
  let props = @presentation.CoreProperties::new()
    .with_title("Q3 Review")
    .with_author("Ada Lovelace")
    .with_subject("Finance")
    .with_keywords("q3, finance")
    .with_description("Quarterly numbers")
    .with_category("Reports")
    .with_content_status("Final")
    .with_created("2026-06-16T09:30:00Z")
    .with_modified("2026-06-16T10:00:00Z")
    .with_last_printed("2026-06-15T08:00:00Z")
    .with_last_modified_by("Grace Hopper")
    .with_revision("3")
    .with_identifier("doc-123")
    .with_language("en-US")
    .with_version("1.2")
  prs.set_core_properties_mut(props)
  assert_true(prs.core_properties() == props)
}

///|
test "core_properties: read → edit → write preserves untouched fields, survives save → open" {
  let prs = @presentation.Presentation::new()
  // The lossless idiom: start from the current properties so unset fields
  // (here the template's revision="1") survive the rewrite.
  prs.set_core_properties_mut(
    prs.core_properties().with_title("Saved").with_author("Ada"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  let cp = reopened.core_properties()
  assert_eq(cp.title.unwrap(), "Saved")
  assert_eq(cp.creator.unwrap(), "Ada")
  // the untouched template field survived because we edited from a read
  assert_eq(cp.revision.unwrap(), "1")
}

///|
test "core_properties: with_core_properties is immutable" {
  let prs = @presentation.Presentation::new()
  let prs2 = prs.with_core_properties(
    @presentation.CoreProperties::new().with_title("New"),
  )
  assert_eq(prs2.core_properties().title.unwrap(), "New")
  // the original is untouched (still the blank template's empty title)
  assert_eq(prs.core_properties().title.unwrap(), "")
}

///|
test "core_properties: with_author aliases with_creator" {
  let a = @presentation.CoreProperties::new().with_author("X")
  let b = @presentation.CoreProperties::new().with_creator("X")
  assert_true(a == b)
  assert_eq(a.creator.unwrap(), "X")
}

///|
test "core_properties: to_xml emits prefixes + xsi:type, omits None fields" {
  let xml = @presentation.CoreProperties::new()
    .with_title("Hi")
    .with_keywords("k")
    .with_created("2026-01-01T00:00:00Z")
    .to_xml()
  assert_true(has_substring(xml, "<dc:title>Hi</dc:title>"))
  assert_true(has_substring(xml, "<cp:keywords>k</cp:keywords>"))
  assert_true(has_substring(xml, "<dcterms:created"))
  assert_true(has_substring(xml, "xsi:type=\"dcterms:W3CDTF\""))
  // a None field is omitted entirely
  assert_eq(has_substring(xml, "<dc:subject"), false)
}

///|
test "core_properties: empty new() emits the root but no field elements" {
  let xml = @presentation.CoreProperties::new().to_xml()
  assert_true(has_substring(xml, "coreProperties"))
  assert_eq(has_substring(xml, "<dc:title"), false)
  assert_eq(has_substring(xml, "<cp:revision"), false)
}

///|
test "core_properties: special characters are XML-escaped + decode back" {
  let prs = @presentation.Presentation::new()
  prs.set_core_properties_mut(
    @presentation.CoreProperties::new().with_title("R&D <plan>"),
  )
  // parse decodes the entities back to the original string
  assert_eq(prs.core_properties().title.unwrap(), "R&D <plan>")
  // the serialised form carries the escaped entity
  let raw = @presentation.CoreProperties::new().with_title("R&D").to_xml()
  assert_true(has_substring(raw, "R&amp;D"))
}
