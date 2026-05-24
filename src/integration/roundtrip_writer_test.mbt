// End-to-end serialize → re-parse golden tests (Phase 4g).
//
// Each test opens one of the three synthetic decks, parses every
// OOXML part, re-serialises it via the package-level writer, replaces
// the part bytes in the Package, saves the Package, and asserts that
// re-opening + re-parsing yields equal model values. This is the
// strongest Phase 4 invariant — any silent data loss across the
// parse/serialise boundary surfaces here.

// --- helpers ---

///|
/// Re-serialise every OOXML part in `pkg` through its package-level
/// writer, mutating the part bytes in place. Returns the modified
/// package so callers can chain `to_bytes` / reopen.
fn re_serialize_all(pkg : @opc.Package) -> @opc.Package raise {
  for p in parts_of(pkg, ct_theme) {
    let parsed = @theme.Theme::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, ct_slide_master) {
    let parsed = @slide_master.SlideMaster::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, ct_slide_layout) {
    let parsed = @slide_master.SlideLayout::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, ct_slide) {
    let parsed = @slide.Slide::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, ct_notes_slide) {
    let parsed = @notes.NotesSlide::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, ct_comment_authors) {
    let parsed = @comments.CommentAuthorList::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, ct_comments) {
    let parsed = @comments.CommentList::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, @oxml.ct_chart) {
    let parsed = @chart.Chart::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  for p in parts_of(pkg, @oxml.ct_chart_ex) {
    let parsed = @chart_ex.ChartEx::parse(p.bytes)
    replace_part_bytes(pkg, p.name, parsed.serialize())
  }
  pkg
}

///|
/// Replace the bytes of an existing part by name. `add_part` rejects
/// duplicates, so we remove first then re-add with the new bytes.
fn replace_part_bytes(
  pkg : @opc.Package,
  name : String,
  bytes : FixedArray[Byte],
) -> Unit raise {
  let original = pkg.require_part(name)
  let ct = original.content_type
  let _ = pkg.remove_part(name)
  let new_part = @opc.Part::new(name, ct, bytes)
  pkg.add_part(new_part)
}

// --- minimal deck ---

///|
test "minimal_deck: parse → serialize → reopen → re-parse preserves Slide" {
  let pkg_in = @opc.Package::open(minimal_deck())
  let pkg_re = re_serialize_all(@opc.Package::open(minimal_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let s_in = @slide.Slide::parse(
    pkg_in.require_part("/ppt/slides/slide1.xml").bytes,
  )
  let s_out = @slide.Slide::parse(
    pkg_out.require_part("/ppt/slides/slide1.xml").bytes,
  )
  assert_true(s_in == s_out)
}

///|
test "minimal_deck: round-trip preserves Theme + SlideMaster + SlideLayout" {
  let pkg_in = @opc.Package::open(minimal_deck())
  let pkg_re = re_serialize_all(@opc.Package::open(minimal_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let t_in = @theme.Theme::parse(
    pkg_in.require_part("/ppt/theme/theme1.xml").bytes,
  )
  let t_out = @theme.Theme::parse(
    pkg_out.require_part("/ppt/theme/theme1.xml").bytes,
  )
  assert_true(t_in == t_out)
  let m_in = @slide_master.SlideMaster::parse(
    pkg_in.require_part("/ppt/slideMasters/slideMaster1.xml").bytes,
  )
  let m_out = @slide_master.SlideMaster::parse(
    pkg_out.require_part("/ppt/slideMasters/slideMaster1.xml").bytes,
  )
  assert_true(m_in == m_out)
  let l_in = @slide_master.SlideLayout::parse(
    pkg_in.require_part("/ppt/slideLayouts/slideLayout1.xml").bytes,
  )
  let l_out = @slide_master.SlideLayout::parse(
    pkg_out.require_part("/ppt/slideLayouts/slideLayout1.xml").bytes,
  )
  assert_true(l_in == l_out)
}

// --- rich deck ---

///|
test "rich_deck: every shape kind survives parse → serialize → re-parse" {
  let pkg_in = @opc.Package::open(rich_deck())
  let pkg_re = re_serialize_all(@opc.Package::open(rich_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let s_in = @slide.Slide::parse(
    pkg_in.require_part("/ppt/slides/slide2.xml").bytes,
  )
  let s_out = @slide.Slide::parse(
    pkg_out.require_part("/ppt/slides/slide2.xml").bytes,
  )
  assert_true(s_in == s_out)
  // Spot-check the typed custGeom AST survives intact.
  match s_out.shapes[2] {
    AutoShape(sp) =>
      match sp.geometry.unwrap() {
        Custom(cg) => assert_eq(cg.paths[0].commands.length(), 4)
        _ => fail("expected Custom geometry on shape[2]")
      }
    _ => fail("expected AutoShape with custGeom")
  }
}

// --- notes + comments deck ---

///|
test "notes_and_comments_deck: NotesSlide + CommentList round-trip" {
  let pkg_in = @opc.Package::open(notes_and_comments_deck())
  let pkg_re = re_serialize_all(@opc.Package::open(notes_and_comments_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let n_in = @notes.NotesSlide::parse(
    pkg_in.require_part("/ppt/notesSlides/notesSlide1.xml").bytes,
  )
  let n_out = @notes.NotesSlide::parse(
    pkg_out.require_part("/ppt/notesSlides/notesSlide1.xml").bytes,
  )
  assert_true(n_in == n_out)
  let cms_in = @comments.CommentList::parse(
    pkg_in.require_part("/ppt/comments/comment1.xml").bytes,
  )
  let cms_out = @comments.CommentList::parse(
    pkg_out.require_part("/ppt/comments/comment1.xml").bytes,
  )
  assert_true(cms_in == cms_out)
  let authors_in = @comments.CommentAuthorList::parse(
    pkg_in.require_part("/ppt/commentAuthors.xml").bytes,
  )
  let authors_out = @comments.CommentAuthorList::parse(
    pkg_out.require_part("/ppt/commentAuthors.xml").bytes,
  )
  assert_true(authors_in == authors_out)
}

// --- blanket guarantee across all three decks ---

///|
test "all decks: serialize → reopen → re-parse changes no parsed value" {
  for bytes in [minimal_deck(), rich_deck(), notes_and_comments_deck()] {
    let pkg_in = @opc.Package::open(bytes)
    let pkg_re = re_serialize_all(@opc.Package::open(bytes))
    let pkg_out = @opc.Package::open(pkg_re.to_bytes())
    // Re-run the no-panic-floor `parse_everything` on both sides and
    // assert each count tuple matches.
    let counts_in = parse_everything(pkg_in)
    let counts_out = parse_everything(pkg_out)
    // Tuple equality without falling back to the deprecated Show impl
    // — assert each slot individually.
    assert_eq(counts_in.0, counts_out.0)
    assert_eq(counts_in.1, counts_out.1)
    assert_eq(counts_in.2, counts_out.2)
    assert_eq(counts_in.3, counts_out.3)
    assert_eq(counts_in.4, counts_out.4)
    assert_eq(counts_in.5, counts_out.5)
    assert_eq(counts_in.6, counts_out.6)
  }
}
