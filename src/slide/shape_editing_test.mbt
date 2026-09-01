// Tests for pinpoint shape editing.
// Reuses `typical_title_slide()` from parser_test.mbt: shapes are
// AutoShape(id=2, "Title 1"), AutoShape(id=3, "Subtitle 2"), Picture(id=4).
//
// `assert_eq` on an `Option` triggers a Show deprecation warning (CI runs
// `--deny-warn`), so we unwrap first and assert on the inner value — the
// same convention `parser_test.mbt` uses.

///|
/// A slide carrying one unmodelled shape (`<p:contentPart>`), which parses
/// as `Shape::Unknown` — used to check the id/name accessors return `None`.
fn slide_with_unknown_shape() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:contentPart r:id=\"rId9\" xmlns:r=\"" +
    off_rel_ns +
    "\"/>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- Shape::id / name ---

///|
test "Shape::id / name read every typed variant; Unknown is None" {
  let slide = @slide.Slide::parse(typical_title_slide())
  assert_eq(slide.shapes[0].id().unwrap(), 2)
  assert_eq(slide.shapes[0].name().unwrap(), "Title 1")
  assert_eq(slide.shapes[2].id().unwrap(), 4) // the picture
  let unknown = @slide.Slide::parse(slide_with_unknown_shape())
  assert_true(unknown.shapes[0].id() is None)
  assert_true(unknown.shapes[0].name() is None)
}

// --- map_shapes ---

///|
test "Slide::map_shapes applies f to every shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // Rename every AutoShape; leave other kinds untouched.
  let renamed = slide.map_shapes(s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "X", })
      other => other
    }
  })
  assert_eq(renamed.shapes[0].name().unwrap(), "X")
  assert_eq(renamed.shapes[1].name().unwrap(), "X")
  assert_eq(renamed.shapes[2].name().unwrap(), "Pic") // picture unchanged
  // Original is untouched (immutable, ADR-003).
  assert_eq(slide.shapes[0].name().unwrap(), "Title 1")
}

// --- by index ---

///|
test "Slide::with_shape_at replaces by index" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // Replace shape 0 with a copy of the picture (shape 2).
  let edited = slide.with_shape_at(0, slide.shapes[2])
  assert_eq(edited.shapes[0].id().unwrap(), 4)
  assert_eq(edited.shapes.length(), 3)
}

///|
test "Slide::with_shape_mapped transforms only the indexed shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_mapped(1, s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Only2", })
      other => other
    }
  })
  assert_eq(edited.shapes[0].name().unwrap(), "Title 1") // untouched
  assert_eq(edited.shapes[1].name().unwrap(), "Only2")
}

///|
test "Slide::with_shape_at / mapped / without raise on bad index" {
  let slide = @slide.Slide::parse(typical_title_slide())
  try slide.with_shape_at(99, slide.shapes[0]) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
  try slide.with_shape_mapped(-1, s => s) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
  try slide.without_shape(99) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- by id ---

///|
test "Slide::with_shape_by_id transforms the matching shape only" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_by_id(3, s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "ById", })
      other => other
    }
  })
  assert_eq(edited.shapes[0].name().unwrap(), "Title 1") // id 2 untouched
  assert_eq(edited.shapes[1].name().unwrap(), "ById") // id 3 changed
  assert_eq(edited.shapes[2].name().unwrap(), "Pic") // id 4 untouched
}

///|
test "Slide::with_shape_by_id raises when the id is absent" {
  let slide = @slide.Slide::parse(typical_title_slide())
  try slide.with_shape_by_id(999, s => s) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- removal ---

///|
test "Slide::without_shape / without_shape_by_id drop one shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let a = slide.without_shape(1)
  assert_eq(a.shapes.length(), 2)
  assert_eq(a.shapes[0].id().unwrap(), 2)
  assert_eq(a.shapes[1].id().unwrap(), 4)
  let b = slide.without_shape_by_id(4)
  assert_eq(b.shapes.length(), 2)
  assert_true(b.shapes.iter().all(s => s.id() != Some(4)))
  try slide.without_shape_by_id(999) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- edits survive serialisation ---

///|
test "an id-targeted rename round-trips through serialize" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_by_id(3, s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Persisted", })
      other => other
    }
  })
  let reparsed = @slide.Slide::parse(edited.serialize())
  assert_eq(reparsed.shapes[1].name().unwrap(), "Persisted")
}

// --- shape id allocation ---

///|
/// A group holding one rectangle, so the recursive id walk has something to
/// descend into. Group children share the slide's `<p:spTree>` id space.
fn group_with_child(group_id : Int, child_id : Int) -> @slide.Shape {
  let child = @slide.AutoShape::rect(
    id=child_id,
    name="Inner",
    x=@units.Emu(0L),
    y=@units.Emu(0L),
    cx=@units.Emu(914_400L),
    cy=@units.Emu(914_400L),
  )
  let g : @slide.GroupShape = {
    id: group_id,
    name: "Group",
    transform: None,
    child_offset: None,
    child_extent: None,
    children: [@slide.AutoShape(child)],
    hyperlink: None,
    extension: [],
  }
  @slide.Group(g)
}

///|
test "Shape::with_id sets the id on every typed variant" {
  let slide = @slide.Slide::parse(typical_title_slide())
  assert_eq(slide.shapes[0].with_id(42).id().unwrap(), 42)
  assert_eq(slide.shapes[2].with_id(43).id().unwrap(), 43)
  assert_eq(group_with_child(10, 11).with_id(44).id().unwrap(), 44)
  // Unknown carries no typed id, so it comes back untouched.
  let unknown = @slide.Slide::parse(slide_with_unknown_shape()).shapes[0]
  assert_eq(unknown.with_id(45), unknown)
}

///|
test "Slide::next_shape_id clears the highest id in use" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // ids 2, 3, 4 are taken.
  assert_eq(slide.next_shape_id(), 5)
  // A group's child competes for the same id space as its parent.
  let with_group = slide.with_shape(group_with_child(10, 20))
  assert_eq(with_group.next_shape_id(), 21)
}

///|
test "Slide::next_shape_id floors at 2 on an empty slide" {
  let empty = @slide.Slide::parse(typical_title_slide()).map_shapes(s => s)
  let cleared = { ..empty, shapes: [], }
  // id 1 belongs to the root spTree, so the first shape id is 2.
  assert_eq(cleared.next_shape_id(), 2)
}

///|
test "Slide::with_shape_auto_id renumbers a colliding shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // Deliberately reuse id 2, which the title already holds.
  let clashing = @slide.AutoShape(
    @slide.AutoShape::rect(
      id=2,
      name="Clash",
      x=@units.Emu(0L),
      y=@units.Emu(0L),
      cx=@units.Emu(914_400L),
      cy=@units.Emu(914_400L),
    ),
  )
  assert_true(slide.with_shape(clashing).duplicate_shape_ids() == [2])
  let fixed = slide.with_shape_auto_id(clashing)
  assert_eq(fixed.shapes[3].id().unwrap(), 5)
  assert_eq(fixed.shapes[3].name().unwrap(), "Clash")
  assert_true(fixed.duplicate_shape_ids() == [])
}

///|
test "Slide::duplicate_shape_ids reports each clashing id once, ascending" {
  let slide = @slide.Slide::parse(typical_title_slide())
  assert_true(slide.duplicate_shape_ids() == [])
  // Two shapes on id 4 and three on id 3 — each id is reported once.
  let clashing = slide
    .with_shape(group_with_child(4, 3))
    .with_shape(
      @slide.AutoShape(
        @slide.AutoShape::rect(
          id=3,
          name="Third",
          x=@units.Emu(0L),
          y=@units.Emu(0L),
          cx=@units.Emu(914_400L),
          cy=@units.Emu(914_400L),
        ),
      ),
    )
  assert_true(clashing.duplicate_shape_ids() == [3, 4])
}
