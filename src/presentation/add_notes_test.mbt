// Tests for `Presentation::set_notes_mut` (speaker notes builder).

///|
test "set_notes_mut: first call creates the notesSlide part + slide rel" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "Hello from the notes pane")

  // The notes part landed.
  let notes_part = prs.pkg.part_by_name("/ppt/notesSlides/notesSlide1.xml")
  assert_true(notes_part is Some(_))

  // The source slide gained a rt_notes_slide relationship pointing at it.
  let mut found_rt_notes = false
  for p in prs.pkg.parts() {
    if p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml") {
      let rels = prs.pkg.relationships_for(p.name)
      if rels.by_type(@opc.rt_notes_slide).length() > 0 {
        found_rt_notes = true
      }
    }
  }
  assert_true(found_rt_notes)
}

///|
test "set_notes_mut: notesSlide carries the text in a body placeholder" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "Remember to thank the team")
  let notes = prs.notes_slides()
  assert_eq(notes.length(), 1)
  let n = notes[0]
  assert_eq(n.shapes.length(), 1)
  match n.shapes[0] {
    AutoShape(a) => {
      let ph = a.placeholder.unwrap()
      assert_eq(ph.ph_type, "body")
      assert_eq(ph.idx, 1)
      let tb = a.text_body.unwrap()
      assert_eq(tb.paragraphs[0].plain_text(), "Remember to thank the team")
    }
    _ => fail("expected AutoShape placeholder")
  }
}

///|
test "set_notes_mut: Override content type registered" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "notes")
  let cts = prs.pkg.content_types()
  let has_notes_override = cts.overrides
    .iter()
    .any(fn(kv) {
      kv.0 == "/ppt/notesSlides/notesSlide1.xml" && kv.1 == @oxml.ct_notes_slide
    })
  assert_true(has_notes_override)
}

///|
test "set_notes_mut: notesSlide.rels points back at source slide" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let notes_rels = prs.pkg.relationships_for("/ppt/notesSlides/notesSlide1.xml")
  let back = notes_rels.by_type(@opc.rt_slide)
  assert_eq(back.length(), 1)
  assert_true(back[0].target.has_suffix(".xml"))
  assert_true(back[0].target_mode is Internal)
}

///|
test "set_notes_mut: second call replaces bytes, doesn't create a new part" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "first version")
  prs.set_notes_mut(0, "second version")
  // Still exactly one notesSlide part.
  let notes_parts = prs.pkg
    .parts()
    .iter()
    .filter(fn(p) { p.content_type == @oxml.ct_notes_slide })
    .collect()
  assert_eq(notes_parts.length(), 1)
  let n = prs.notes_slides()[0]
  match n.shapes[0] {
    AutoShape(a) =>
      assert_eq(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        "second version",
      )
    _ => fail("expected AutoShape")
  }
}

///|
test "set_notes_mut: out-of-range slide_idx raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try prs.set_notes_mut(99, "nope") catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "set_notes_mut: full save → reopen round-trips" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "round-trip me")
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let notes = prs2.notes_slides()
  assert_eq(notes.length(), 1)
  match notes[0].shapes[0] {
    AutoShape(a) =>
      assert_eq(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        "round-trip me",
      )
    _ => fail("expected AutoShape")
  }
}

///|
test "set_notes_mut: XML-special chars in text get escaped safely" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "Q&A: <intro> & </outro>")
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  match prs2.notes_slides()[0].shapes[0] {
    AutoShape(a) =>
      assert_eq(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        "Q&A: <intro> & </outro>",
      )
    _ => fail("expected AutoShape")
  }
}

// --- notes-master synthesis ---

///|
test "set_notes_mut: synthesises a notesMaster on first call" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // Before: no notes master in the package.
  let before = prs.pkg
    .parts()
    .iter()
    .filter(fn(p) { p.content_type == @oxml.ct_notes_master })
    .count()
  assert_eq(before, 0)
  prs.set_notes_mut(0, "first")
  // After: exactly one notesMaster part.
  let after = prs.pkg
    .parts()
    .iter()
    .filter(fn(p) { p.content_type == @oxml.ct_notes_master })
    .count()
  assert_eq(after, 1)
}

///|
test "set_notes_mut: notesMaster references a duplicate theme (theme2)" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let nm_rels = prs.pkg.relationships_for("/ppt/notesMasters/notesMaster1.xml")
  let theme_rels = nm_rels.by_type(@opc.rt_theme)
  assert_eq(theme_rels.length(), 1)
  // Points at theme2.xml — a duplicate of theme1 that PowerPoint
  // requires for the notes master (sharing the main theme triggers
  // the repair banner).
  assert_true(theme_rels[0].target.has_suffix("theme2.xml"))
  // And the duplicate theme part is actually present.
  assert_true(prs.pkg.part_by_name("/ppt/theme/theme2.xml") is Some(_))
}

///|
test "set_notes_mut: presentation.xml gains a notesMasterIdLst entry" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let pres = prs.presentation_part().unwrap()
  assert_true(pres.notes_master_id is Some(_))
}

///|
test "set_notes_mut: second call reuses the existing notesMaster" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "first")
  prs.set_notes_mut(1, "second")
  // Still exactly one notesMaster part.
  let nm_count = prs.pkg
    .parts()
    .iter()
    .filter(fn(p) { p.content_type == @oxml.ct_notes_master })
    .count()
  assert_eq(nm_count, 1)
}

///|
test "set_notes_mut: notesSlide.rels also points at the notesMaster" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let nm_in_notes = prs.pkg
    .relationships_for("/ppt/notesSlides/notesSlide1.xml")
    .by_type(@opc.rt_notes_master)
  assert_eq(nm_in_notes.length(), 1)
}
