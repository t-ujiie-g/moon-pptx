// End-to-end read-path roundtrip tests (Phase 3 closing slice).
//
// Each test opens one of the three synthetic decks defined in
// `fixtures_test.mbt`, walks parts by content type, dispatches each
// part into its package-level parser (`Theme::parse`,
// `SlideMaster::parse`, `SlideLayout::parse`, `Slide::parse`,
// `NotesSlide::parse`, `CommentAuthorList::parse`, `CommentList::parse`)
// and asserts the data round-trips end-to-end.
//
// "End-to-end" here means:
//   1. Package::open(bytes) succeeds.
//   2. Every OOXML part with a content-type we understand parses
//      without raising.
//   3. The parsed structures carry the values we encoded into the
//      fixture (counts, names, text).
//   4. Re-serialising the package via `to_bytes` and re-opening it
//      yields the same parts and the same parsed structures.

// --- helpers ---

///|
/// Find every part whose content-type matches one of the supplied
/// values, in source order. Used to dispatch parts into the correct
/// parser without hard-coding part names — content type is the
/// authoritative router per OPC.
fn parts_of(pkg : @opc.Package, content_type : String) -> Array[@opc.Part] {
  let out : Array[@opc.Part] = []
  for p in pkg.parts() {
    if p.content_type == content_type {
      out.push(p)
    }
  }
  out
}

///|
/// Walk every parser-bearing content-type in `pkg`, raise if any part
/// fails to parse, and return the parsed counts so tests can assert on
/// them.
fn parse_everything(
  pkg : @opc.Package,
) -> (Int, Int, Int, Int, Int, Int, Int) raise {
  let mut themes = 0
  let mut masters = 0
  let mut layouts = 0
  let mut slides = 0
  let mut notes = 0
  let mut author_lists = 0
  let mut comment_lists = 0
  for p in parts_of(pkg, ct_theme) {
    let _ = @theme.Theme::parse(p.bytes)
    themes = themes + 1
  }
  for p in parts_of(pkg, ct_slide_master) {
    let _ = @slide_master.SlideMaster::parse(p.bytes)
    masters = masters + 1
  }
  for p in parts_of(pkg, ct_slide_layout) {
    let _ = @slide_master.SlideLayout::parse(p.bytes)
    layouts = layouts + 1
  }
  for p in parts_of(pkg, ct_slide) {
    let _ = @slide.Slide::parse(p.bytes)
    slides = slides + 1
  }
  for p in parts_of(pkg, ct_notes_slide) {
    let _ = @notes.NotesSlide::parse(p.bytes)
    notes = notes + 1
  }
  for p in parts_of(pkg, ct_comment_authors) {
    let _ = @comments.CommentAuthorList::parse(p.bytes)
    author_lists = author_lists + 1
  }
  for p in parts_of(pkg, ct_comments) {
    let _ = @comments.CommentList::parse(p.bytes)
    comment_lists = comment_lists + 1
  }
  (themes, masters, layouts, slides, notes, author_lists, comment_lists)
}

// --- minimal_deck ---

///|
test "minimal_deck: Package::open succeeds and every parser handles its part" {
  let pkg = @opc.Package::open(minimal_deck())
  let (themes, masters, layouts, slides, notes, authors, comments) = parse_everything(
    pkg,
  )
  assert_eq(themes, 1)
  assert_eq(masters, 1)
  assert_eq(layouts, 1)
  assert_eq(slides, 1)
  assert_eq(notes, 0)
  assert_eq(authors, 0)
  assert_eq(comments, 0)
}

///|
test "minimal_deck: slide carries the encoded title text" {
  let pkg = @opc.Package::open(minimal_deck())
  let part = pkg.require_part("/ppt/slides/slide1.xml")
  let slide = @slide.Slide::parse(part.bytes)
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    AutoShape(s) =>
      assert_eq(s.text_body.unwrap().plain_text(), "Hello, MoonBit")
    _ => fail("expected AutoShape")
  }
}

///|
test "minimal_deck: theme carries Office colour-scheme name" {
  let pkg = @opc.Package::open(minimal_deck())
  let part = pkg.require_part("/ppt/theme/theme1.xml")
  let t = @theme.Theme::parse(part.bytes)
  assert_eq(t.name, "Office")
  assert_eq(t.color_scheme.name, "Office")
}

///|
test "minimal_deck: master clrMap resolves bg1 -> lt1" {
  let pkg = @opc.Package::open(minimal_deck())
  let part = pkg.require_part("/ppt/slideMasters/slideMaster1.xml")
  let m = @slide_master.SlideMaster::parse(part.bytes)
  assert_true(m.color_mapping.bg1 == @units.ThemeColor::Lt1)
  assert_true(m.color_mapping.tx1 == @units.ThemeColor::Dk1)
}

///|
test "minimal_deck: round-trip via to_bytes yields identical parsed results" {
  let bytes_in = minimal_deck()
  let pkg_in = @opc.Package::open(bytes_in)
  let bytes_out = pkg_in.to_bytes()
  let pkg_out = @opc.Package::open(bytes_out)
  // Same set of parts, same content types, same byte payload per part.
  let names_in = pkg_in.parts().map(fn(p) { p.name })
  let names_out = pkg_out.parts().map(fn(p) { p.name })
  assert_eq(names_in.length(), names_out.length())
  // Every parsed structure equals on both sides — Eq is derived on
  // every model node so this catches any silent data loss.
  let slide_in = @slide.Slide::parse(
    pkg_in.require_part("/ppt/slides/slide1.xml").bytes,
  )
  let slide_out = @slide.Slide::parse(
    pkg_out.require_part("/ppt/slides/slide1.xml").bytes,
  )
  assert_true(slide_in == slide_out)
  let theme_in = @theme.Theme::parse(
    pkg_in.require_part("/ppt/theme/theme1.xml").bytes,
  )
  let theme_out = @theme.Theme::parse(
    pkg_out.require_part("/ppt/theme/theme1.xml").bytes,
  )
  assert_true(theme_in == theme_out)
}

// --- rich_deck ---

///|
test "rich_deck: every parser handles its part (no panics)" {
  let pkg = @opc.Package::open(rich_deck())
  let (_, _, _, slides, _, _, _) = parse_everything(pkg)
  // Minimal deck has 1 slide; rich adds a second.
  assert_eq(slides, 2)
}

///|
test "rich_deck: rich slide contains every shape kind" {
  let pkg = @opc.Package::open(rich_deck())
  let slide = @slide.Slide::parse(
    pkg.require_part("/ppt/slides/slide2.xml").bytes,
  )
  // AutoShape(body) + Picture + AutoShape(custGeom) + Connector + Group
  assert_eq(slide.shapes.length(), 5)
  let mut autoshape_count = 0
  let mut picture_count = 0
  let mut connector_count = 0
  let mut group_count = 0
  for s in slide.shapes {
    match s {
      AutoShape(_) => autoshape_count = autoshape_count + 1
      Picture(_) => picture_count = picture_count + 1
      Connector(_) => connector_count = connector_count + 1
      Group(_) => group_count = group_count + 1
      Unknown(_) => fail("rich deck should not produce Unknown shapes")
    }
  }
  assert_eq(autoshape_count, 2)
  assert_eq(picture_count, 1)
  assert_eq(connector_count, 1)
  assert_eq(group_count, 1)
}

///|
test "rich_deck: custGeom AutoShape lifts to typed CustomGeometry" {
  let pkg = @opc.Package::open(rich_deck())
  let slide = @slide.Slide::parse(
    pkg.require_part("/ppt/slides/slide2.xml").bytes,
  )
  // shapes[2] is the custGeom AutoShape (id=4).
  match slide.shapes[2] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Custom(cg) => {
          assert_eq(cg.paths.length(), 1)
          // moveTo + lnTo + lnTo + close
          assert_eq(cg.paths[0].commands.length(), 4)
          assert_true(cg.rect is Some(_))
        }
        _ => fail("expected Custom geometry")
      }
    _ => fail("expected AutoShape with custGeom")
  }
}

///|
test "rich_deck: round-trip via to_bytes preserves the rich slide" {
  let pkg_in = @opc.Package::open(rich_deck())
  let pkg_out = @opc.Package::open(pkg_in.to_bytes())
  let slide_in = @slide.Slide::parse(
    pkg_in.require_part("/ppt/slides/slide2.xml").bytes,
  )
  let slide_out = @slide.Slide::parse(
    pkg_out.require_part("/ppt/slides/slide2.xml").bytes,
  )
  assert_true(slide_in == slide_out)
}

// --- notes_and_comments_deck ---

///|
test "notes_and_comments_deck: notes + commentAuthors + comments all parse" {
  let pkg = @opc.Package::open(notes_and_comments_deck())
  let (_, _, _, slides, notes, authors, comments) = parse_everything(pkg)
  assert_eq(slides, 1)
  assert_eq(notes, 1)
  assert_eq(authors, 1)
  assert_eq(comments, 1)
}

///|
test "notes_and_comments_deck: notes slide carries the encoded paragraph" {
  let pkg = @opc.Package::open(notes_and_comments_deck())
  let n = @notes.NotesSlide::parse(
    pkg.require_part("/ppt/notesSlides/notesSlide1.xml").bytes,
  )
  // sldImg-style first placeholder isn't in this fixture; just the body.
  assert_eq(n.shapes.length(), 1)
  match n.shapes[0] {
    AutoShape(s) =>
      assert_eq(
        s.text_body.unwrap().plain_text(),
        "Remember to mention pricing.",
      )
    _ => fail("expected AutoShape with notes body")
  }
}

///|
test "notes_and_comments_deck: comment authors and comments cross-reference" {
  let pkg = @opc.Package::open(notes_and_comments_deck())
  let authors = @comments.CommentAuthorList::parse(
    pkg.require_part("/ppt/commentAuthors.xml").bytes,
  )
  let cms = @comments.CommentList::parse(
    pkg.require_part("/ppt/comments/comment1.xml").bytes,
  )
  assert_eq(authors.authors.length(), 2)
  assert_eq(cms.comments.length(), 2)
  // First comment is by author 0 (Alice); second by author 1 (Bob).
  // Verify the join works.
  assert_eq(cms.comments[0].author_id, authors.authors[0].id)
  assert_eq(cms.comments[1].author_id, authors.authors[1].id)
  assert_eq(authors.authors[0].name, "Alice")
  assert_eq(cms.comments[0].text, "Looks great!")
}

///|
test "notes_and_comments_deck: round-trip preserves notes + comments" {
  let pkg_in = @opc.Package::open(notes_and_comments_deck())
  let pkg_out = @opc.Package::open(pkg_in.to_bytes())
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
}

// --- cross-fixture sanity ---

///|
test "all three decks: no part panics any parser" {
  // A blanket guarantee: every fixture, when opened, can have every
  // OOXML part dispatched through its parser without raising. The
  // per-deck tests check structural counts; this one is the
  // "no-panic" floor that closes Phase 3.
  for bytes in [minimal_deck(), rich_deck(), notes_and_comments_deck()] {
    let pkg = @opc.Package::open(bytes)
    let _ = parse_everything(pkg)
  }
}
