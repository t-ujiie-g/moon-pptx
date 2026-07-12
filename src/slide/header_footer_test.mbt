// Tests for slide date / footer / slide-number placeholders.

///|
/// Find the first placeholder AutoShape of `kind` on the slide.
fn find_ph(
  slide : @slide.Slide,
  kind : @slide.PlaceholderType,
) -> @slide.AutoShape? {
  for s in slide.shapes {
    match s {
      AutoShape(a) =>
        match a.placeholder {
          Some(ph) => if ph.kind() == kind { return Some(a) }
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
test "with_footer: adds a footer placeholder carrying the text" {
  let slide = @slide.Slide::parse(typical_title_slide()).with_footer(
    "Confidential",
  )
  let ftr = find_ph(slide, Ftr).unwrap()
  assert_eq(ftr.placeholder.unwrap().ph_type, "ftr")
  assert_eq(ftr.text_body.unwrap().plain_text(), "Confidential")
}

///|
test "with_footer: is idempotent (replaces, not duplicates)" {
  let slide = @slide.Slide::parse(typical_title_slide())
    .with_footer("A")
    .with_footer("B")
  let mut count = 0
  for s in slide.shapes {
    match s {
      AutoShape(a) =>
        match a.placeholder {
          Some(ph) => if ph.kind() is Ftr { count = count + 1 }
          None => ()
        }
      _ => ()
    }
  }
  assert_eq(count, 1)
  assert_eq(find_ph(slide, Ftr).unwrap().text_body.unwrap().plain_text(), "B")
}

///|
test "with_slide_number: true adds a sldNum field; false removes it" {
  let on = @slide.Slide::parse(typical_title_slide()).with_slide_number(true)
  let sp = find_ph(on, SldNum).unwrap()
  assert_eq(sp.placeholder.unwrap().ph_type, "sldNum")
  assert_eq(sp.placeholder.unwrap().idx, 12)
  // The body holds a slidenum field — serialised as <a:fld type="slidenum">.
  let xml = @oxml.bytes_to_string(on.serialize())
  assert_true(char_index_of(xml, "type=\"slidenum\"") >= 0)
  // Toggling off removes it.
  let off = on.with_slide_number(false)
  assert_true(find_ph(off, SldNum) is None)
}

///|
test "with_date: Auto emits a datetime field; Fixed emits literal text" {
  let auto = @slide.Slide::parse(typical_title_slide()).with_date(Auto)
  assert_eq(find_ph(auto, Dt).unwrap().placeholder.unwrap().ph_type, "dt")
  let auto_xml = @oxml.bytes_to_string(auto.serialize())
  assert_true(char_index_of(auto_xml, "type=\"datetime1\"") >= 0)
  let fixed = @slide.Slide::parse(typical_title_slide()).with_date(
    Fixed("2026-05-29"),
  )
  assert_eq(
    find_ph(fixed, Dt).unwrap().text_body.unwrap().plain_text(),
    "2026-05-29",
  )
}

///|
test "header/footer placeholders round-trip through serialize" {
  let slide = @slide.Slide::parse(typical_title_slide())
    .with_footer("Footer")
    .with_slide_number(true)
    .with_date(Fixed("Today"))
  let reparsed = @slide.Slide::parse(slide.serialize())
  assert_eq(
    find_ph(reparsed, Ftr).unwrap().text_body.unwrap().plain_text(),
    "Footer",
  )
  assert_true(find_ph(reparsed, SldNum) is Some(_))
  assert_eq(
    find_ph(reparsed, Dt).unwrap().text_body.unwrap().plain_text(),
    "Today",
  )
}
