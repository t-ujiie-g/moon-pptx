// Tests for pinpoint shape editing (roadmap v0.3 B4).
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
  fixture_bytes(xml)
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
  let renamed = slide.map_shapes(fn(s) {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "X" })
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
  let edited = slide.with_shape_mapped(1, fn(s) {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Only2" })
      other => other
    }
  })
  assert_eq(edited.shapes[0].name().unwrap(), "Title 1") // untouched
  assert_eq(edited.shapes[1].name().unwrap(), "Only2")
}

///|
test "Slide::with_shape_at / mapped / without raise on bad index" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let r1 = try? slide.with_shape_at(99, slide.shapes[0])
  assert_true(r1 is Err(_))
  let r2 = try? slide.with_shape_mapped(-1, fn(s) { s })
  assert_true(r2 is Err(_))
  let r3 = try? slide.without_shape(99)
  assert_true(r3 is Err(_))
}

// --- by id ---

///|
test "Slide::with_shape_by_id transforms the matching shape only" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_by_id(3, fn(s) {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "ById" })
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
  let r = try? slide.with_shape_by_id(999, fn(s) { s })
  assert_true(r is Err(_))
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
  assert_true(b.shapes.iter().all(fn(s) { s.id() != Some(4) }))
  let miss = try? slide.without_shape_by_id(999)
  assert_true(miss is Err(_))
}

// --- edits survive serialisation ---

///|
test "B4: an id-targeted rename round-trips through serialize" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_by_id(3, fn(s) {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Persisted" })
      other => other
    }
  })
  let reparsed = @slide.Slide::parse(edited.serialize())
  assert_eq(reparsed.shapes[1].name().unwrap(), "Persisted")
}
