// Slide-section API tests.

///|
/// A fresh deck with `n` slides on layout 0.
fn deck_with_slides(n : Int) -> @presentation.Presentation raise {
  let prs = @presentation.Presentation::new()
  for _ in 0..<n {
    let _ = prs.add_slide_mut(0)
  }
  prs
}

///|
/// A named part of the saved package as a string, for raw-XML
/// assertions (shared across this test package).
fn saved_part_xml(
  prs : @presentation.Presentation,
  name : String,
) -> String raise {
  let pkg = @opc.Package::open(prs.save())
  @oxml.bytes_to_string(pkg.require_part(name).bytes)
}

///|
test "set_sections_mut: partitions the deck and reads back" {
  let prs = deck_with_slides(4)
  prs.set_sections_mut([
    { title: "Introduction", start: 0 },
    { title: "Content", start: 1 },
    { title: "Conclusion", start: 3 },
  ])
  let sections = prs.sections()
  assert_eq(sections.length(), 3)
  assert_true(sections[0] == { title: "Introduction", start: 0 })
  assert_true(sections[1] == { title: "Content", start: 1 })
  assert_true(sections[2] == { title: "Conclusion", start: 3 })
  // The raw XML carries the fixed ext URI, the p14 section list, and
  // one sldId per slide, matching <p:sldIdLst>.
  let xml = saved_part_xml(prs, "/ppt/presentation.xml")
  assert_true(xml.contains(@oxml.section_list_ext_uri))
  assert_true(xml.contains("name=\"Introduction\""))
  assert_true(xml.contains("name=\"Conclusion\""))
  let ids = prs.presentation_part().unwrap().sld_ids
  assert_eq(ids.length(), 4)
  // Slide 3 (index) belongs to "Conclusion": its sldId appears twice —
  // once in <p:sldIdLst>, once in the section's list.
  let mut hits = 0
  let needle = "id=\"" + ids[3].id.to_string() + "\""
  let mut rest = xml
  while rest.find(needle) is Some(off) {
    hits = hits + 1
    rest = rest.view(start_offset=off + needle.length()).to_owned()
  }
  assert_eq(hits, 2)
}

///|
test "sections survive save -> reopen" {
  let prs = deck_with_slides(2)
  prs.set_sections_mut([
    { title: "冒頭", start: 0 },
    { title: "本編", start: 1 },
  ])
  let reopened = @presentation.Presentation::open(prs.save())
  let sections = reopened.sections()
  assert_eq(sections.length(), 2)
  assert_eq(sections[0].title, "冒頭")
  assert_eq(sections[1].start, 1)
}

///|
test "set_sections_mut: setting again replaces, never duplicates" {
  let prs = deck_with_slides(2)
  prs.set_sections_mut([{ title: "First", start: 0 }])
  prs.set_sections_mut([{ title: "Second", start: 0 }])
  let sections = prs.sections()
  assert_eq(sections.length(), 1)
  assert_eq(sections[0].title, "Second")
  let xml = saved_part_xml(prs, "/ppt/presentation.xml")
  assert_true(!xml.contains("First"))
  // Exactly one section ext in the file.
  let first = xml.find(@oxml.section_list_ext_uri).unwrap()
  let rest = xml.view(start_offset=first + 1).to_owned()
  assert_true(rest.find(@oxml.section_list_ext_uri) is None)
}

///|
test "set_sections_mut: empty array removes all sections" {
  let prs = deck_with_slides(2)
  prs.set_sections_mut([{ title: "All", start: 0 }])
  prs.set_sections_mut([])
  assert_eq(prs.sections().length(), 0)
  assert_true(
    saved_part_xml(prs, "/ppt/presentation.xml").find(
      @oxml.section_list_ext_uri,
    )
    is None,
  )
}

///|
test "set_sections_mut: an empty section (equal starts) is representable" {
  let prs = deck_with_slides(2)
  prs.set_sections_mut([
    { title: "Empty", start: 0 },
    { title: "Everything", start: 0 },
  ])
  let sections = prs.sections()
  assert_eq(sections.length(), 2)
  assert_true(sections[0] == { title: "Empty", start: 0 })
  assert_true(sections[1] == { title: "Everything", start: 0 })
}

///|
test "add_section_mut: inserts in slide order" {
  let prs = deck_with_slides(3)
  prs.add_section_mut(title="Intro", start=0)
  prs.add_section_mut(title="Late", start=2)
  prs.add_section_mut(title="Middle", start=1)
  let sections = prs.sections()
  assert_eq(sections.length(), 3)
  assert_eq(sections[0].title, "Intro")
  assert_eq(sections[1].title, "Middle")
  assert_eq(sections[2].title, "Late")
}

///|
test "set_sections_mut: validation errors" {
  let prs = deck_with_slides(2)
  // First section must start at slide 0.
  try prs.set_sections_mut([{ title: "Late", start: 1 }]) catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed for a non-zero first start")
  } noraise {
    _ => fail("expected Malformed for a non-zero first start")
  }
  // Starts must be non-decreasing.
  try
    prs.set_sections_mut([
      { title: "A", start: 0 },
      { title: "B", start: 1 },
      { title: "C", start: 0 },
    ])
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed for out-of-order starts")
  } noraise {
    _ => fail("expected Malformed for out-of-order starts")
  }
  // Starts must be within the deck.
  try
    prs.set_sections_mut([{ title: "A", start: 0 }, { title: "B", start: 3 }])
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed for an out-of-range start")
  } noraise {
    _ => fail("expected Malformed for an out-of-range start")
  }
  // Nothing was written by the failed calls.
  assert_eq(prs.sections().length(), 0)
}

///|
test "with_sections: immutable counterpart leaves the original untouched" {
  let prs = deck_with_slides(1)
  let sectioned = prs.with_sections([{ title: "Only", start: 0 }])
  assert_eq(prs.sections().length(), 0)
  assert_eq(sectioned.sections().length(), 1)
}
