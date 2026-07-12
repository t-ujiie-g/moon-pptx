// Tests for the compile-time placeholder schema.
//
// The compile-time guarantee — e.g. `.body()` on `LayoutSlide[TitleSlide]`
// being a type error — can't be exercised at runtime; these tests cover the
// values each typed constructor produces, the layout synthesis, and round-trip.

///|
/// True if the deck has a layout of `layout_type`.
fn has_layout_of(
  prs : @presentation.Presentation,
  layout_type : @slide_master.SlideLayoutType,
) -> Bool raise {
  for l in prs.slide_layouts() {
    if l.layout_type == layout_type {
      return true
    }
  }
  false
}

///|
test "title slide: title + subtitle round-trip + layout synthesised" {
  let prs = @presentation.Presentation::new()
  let _ = prs
    .add_title_slide_mut()
    .title("Welcome")
    .subtitle("Q3 review")
    .finish_mut()
  assert_true(has_layout_of(prs, @slide_master.SlideLayoutType::Title))
  let prs2 = @presentation.Presentation::open(prs.save())
  assert_eq(prs2.slides().length(), 1)
  let s = prs2.slides()[0]
  assert_true(s.title() is Some(_)) // ctrTitle matches title()
  assert_true(s.placeholder(@slide.PlaceholderType::SubTitle) is Some(_))
}

///|
test "title-and-content slide: title + body" {
  let prs = @presentation.Presentation::new()
  let _ = prs
    .add_title_content_slide_mut()
    .title("Agenda")
    .body("First point")
    .finish_mut()
  assert_true(has_layout_of(prs, @slide_master.SlideLayoutType::Object))
  let s = @presentation.Presentation::open(prs.save()).slides()[0]
  assert_true(s.title() is Some(_))
  assert_true(s.body() is Some(_))
}

///|
test "section header: title + body" {
  let prs = @presentation.Presentation::new()
  let _ = prs
    .add_section_header_slide_mut()
    .title("Part II")
    .body("The deep dive")
    .finish_mut()
  assert_true(has_layout_of(prs, @slide_master.SlideLayoutType::SecHead))
  let s = @presentation.Presentation::open(prs.save()).slides()[0]
  assert_true(s.title() is Some(_))
  assert_true(s.body() is Some(_))
}

///|
test "title-only: just a title" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_title_only_slide_mut().title("Section break").finish_mut()
  assert_true(has_layout_of(prs, @slide_master.SlideLayoutType::TitleOnly))
  let s = @presentation.Presentation::open(prs.save()).slides()[0]
  assert_true(s.title() is Some(_))
  assert_eq(s.placeholders().length(), 1)
}

///|
test "blank typed slide: no placeholders" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_blank_typed_slide_mut().finish_mut()
  let s = @presentation.Presentation::open(prs.save()).slides()[0]
  assert_eq(s.placeholders().length(), 0)
}

///|
test "layout synthesis is idempotent across same-type slides" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_title_slide_mut().title("A").finish_mut()
  let _ = prs.add_title_slide_mut().title("B").finish_mut()
  // Both slides share one synthesised "title" layout.
  let mut title_layouts = 0
  for l in prs.slide_layouts() {
    if l.layout_type == @slide_master.SlideLayoutType::Title {
      title_layouts = title_layouts + 1
    }
  }
  assert_eq(title_layouts, 1)
  assert_eq(@presentation.Presentation::open(prs.save()).slides().length(), 2)
}

///|
test "successive typed layouts attach to the same (main) master" {
  // Regression: with a second master present (define_master), synthesising two
  // layouts must keep attaching them to the main master. `replace_part_bytes`
  // reorders parts, so a "first in package order" pick used to drift to the
  // wrong master and split the two layouts apart.
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(@presentation.MasterDefinition::new("Extra"))
  let _ = prs.add_section_header_slide_mut().title("A").finish_mut()
  let _ = prs.add_title_content_slide_mut().title("B").body("b").finish_mut()
  let prs2 = @presentation.Presentation::open(prs.save())
  // The main master accumulated both synthesised layouts (blank + secHead +
  // obj = 3 refs); the bug split them across masters, leaving max 2.
  let mut max_layouts = 0
  for m in prs2.slide_masters() {
    if m.layout_refs.length() > max_layouts {
      max_layouts = m.layout_refs.length()
    }
  }
  assert_eq(max_layouts, 3)
}

///|
test "mixed deck: several typed layouts coexist and reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_title_slide_mut().title("Deck").subtitle("2026").finish_mut()
  let _ = prs.add_section_header_slide_mut().title("Intro").finish_mut()
  let _ = prs
    .add_title_content_slide_mut()
    .title("Details")
    .body("Body text")
    .finish_mut()
  let prs2 = @presentation.Presentation::open(prs.save())
  assert_eq(prs2.slides().length(), 3)
  assert_true(has_layout_of(prs2, @slide_master.SlideLayoutType::Title))
  assert_true(has_layout_of(prs2, @slide_master.SlideLayoutType::SecHead))
  assert_true(has_layout_of(prs2, @slide_master.SlideLayoutType::Object))
}
