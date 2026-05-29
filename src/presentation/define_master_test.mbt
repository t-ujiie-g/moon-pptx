// Tests for Presentation::define_master (roadmap v0.3 C1).

///|
fn rect(x : Int64, y : Int64, cx : Int64, cy : Int64) -> @slide.Transform {
  {
    offset: { x: @units.Emu(x), y: @units.Emu(y) },
    extent: { cx: @units.Emu(cx), cy: @units.Emu(cy) },
  }
}

///|
/// Whether `needle` occurs in `hay`.
fn has_substring(hay : String, needle : String) -> Bool {
  let hn = hay.length()
  let nn = needle.length()
  let mut i = 0
  while i + nn <= hn {
    let mut j = 0
    while j < nn && hay[i + j] == needle[j] {
      j = j + 1
    }
    if j == nn {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn brand_master() -> @presentation.MasterDefinition {
  @presentation.MasterDefinition::new("Brand")
  .with_placeholder(
    @slide.PlaceholderType::Title,
    rect(838200L, 365125L, 10515600L, 1325563L),
  )
  .with_placeholder(
    @slide.PlaceholderType::Body,
    rect(838200L, 1825625L, 10515600L, 4351338L),
    default_text="Click to edit",
  )
  .with_footer("ACME Confidential")
  .with_slide_number(true)
  .with_date(true)
}

///|
test "define_master: appends a master, registered in sldMasterIdLst" {
  let prs = @presentation.Presentation::new()
  let before = prs.slide_masters().length()
  let idx = prs.define_master(brand_master())
  assert_eq(idx, before) // appended at the end
  assert_eq(prs.slide_masters().length(), before + 1)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_master_ids.length(), before + 1)
}

///|
test "define_master: master part carries placeholders + footer text" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  let master = prs.pkg
    .part_by_name("/ppt/slideMasters/slideMaster2.xml")
    .unwrap()
  let xml = @oxml.bytes_to_string(master.bytes)
  assert_true(has_substring(xml, "type=\"title\""))
  assert_true(has_substring(xml, "type=\"body\""))
  assert_true(has_substring(xml, "type=\"ftr\""))
  assert_true(has_substring(xml, "type=\"sldNum\""))
  assert_true(has_substring(xml, "type=\"dt\""))
  assert_true(has_substring(xml, "ACME Confidential"))
  assert_true(has_substring(xml, "Click to edit"))
  assert_true(has_substring(xml, "<p:clrMap "))
  assert_true(has_substring(xml, "<p:sldLayoutIdLst>"))
  // A master without an explicit background still gets the default bgRef
  // (a master with no <p:bg> trips PowerPoint's repair banner).
  assert_true(has_substring(xml, "<p:bg>"))
}

///|
test "define_master: layout part exists and references the master" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  assert_true(
    prs.pkg.part_by_name("/ppt/slideLayouts/slideLayout2.xml") is Some(_),
  )
  // The layout's .rels points back at the master.
  let rels = prs.pkg
    .part_by_name("/ppt/slideLayouts/_rels/slideLayout2.xml.rels")
    .unwrap()
  let rels_xml = @oxml.bytes_to_string(rels.bytes)
  assert_true(has_substring(rels_xml, "slideMaster2.xml"))
}

///|
test "define_master: deck saves and reopens with both masters" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.slide_masters().length(), 2)
  // The new master + layout survived the zip round-trip.
  assert_true(
    reopened.pkg.part_by_name("/ppt/slideMasters/slideMaster2.xml") is Some(_),
  )
  assert_true(
    reopened.pkg.part_by_name("/ppt/slideLayouts/slideLayout2.xml") is Some(_),
  )
}

///|
test "define_master: a slide can be added on the new layout" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  // slide_layouts() now lists the blank layout + the new one; add on the last.
  let last = prs.slide_layouts().length() - 1
  let _ = prs.add_slide_mut(last)
  assert_eq(prs.slides().length(), 1)
  // Round-trips.
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.slides().length(), 1)
}

///|
test "define_master: new master gets its own theme (repair-clean)" {
  let prs = @presentation.Presentation::new()
  let themes_before = count_theme_parts(prs)
  let _ = prs.define_master(brand_master())
  // A dedicated theme part was added — two masters sharing one theme trips
  // PowerPoint's repair prompt.
  assert_eq(count_theme_parts(prs), themes_before + 1)
  // The new master references a theme other than the original master's.
  let m1 = @oxml.bytes_to_string(
    prs.pkg
    .part_by_name("/ppt/slideMasters/_rels/slideMaster1.xml.rels")
    .unwrap().bytes,
  )
  let m2 = @oxml.bytes_to_string(
    prs.pkg
    .part_by_name("/ppt/slideMasters/_rels/slideMaster2.xml.rels")
    .unwrap().bytes,
  )
  // slideMaster1 uses theme1; slideMaster2 must not.
  assert_true(has_substring(m1, "theme1.xml"))
  assert_false(has_substring(m2, "theme1.xml"))
}

///|
test "define_master: layout declares the placeholders so slides inherit geometry" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  // The generated layout carries the footer / date / number placeholders
  // (with positions) — without them a slide's footer renders unpositioned.
  let layout = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/ppt/slideLayouts/slideLayout2.xml").unwrap().bytes,
  )
  assert_true(has_substring(layout, "type=\"ftr\""))
  assert_true(has_substring(layout, "type=\"dt\""))
  assert_true(has_substring(layout, "type=\"sldNum\""))
  // …and the footer placeholder has an explicit position to inherit.
  assert_true(has_substring(layout, "<a:off x=\"3124200\""))
}

///|
fn count_theme_parts(prs : @presentation.Presentation) -> Int {
  let mut n = 0
  for p in prs.pkg.parts() {
    if has_substring(p.name, "/ppt/theme/theme") {
      n = n + 1
    }
  }
  n
}

///|
test "define_master: new master id clears existing layout ids (no collision)" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_master_ids.length(), 2)
  // slideMaster1 is 2147483648 with its layout at 2147483649; master/layout
  // ids share one space, so the new master must clear 2147483649 (reusing it
  // trips PowerPoint's repair). The first free id is 2147483650.
  assert_true(pres.sld_master_ids[1].id >= 2147483650L)
}
