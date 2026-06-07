// Tests for the generic typed-placeholder builder (roadmap M1 building block).

///|
test "Slide::with_placeholder appends a typed placeholder, idempotent per kind+idx" {
  let s0 = @slide.Slide::parse(slide_with_bg(""))
  let s1 = s0.with_placeholder(@slide.PlaceholderType::Title, 0, text="Hello")
  assert_true(s1.title() is Some(_))
  // Re-setting the same kind+idx replaces rather than duplicates.
  let s2 = s1.with_placeholder(@slide.PlaceholderType::Title, 0, text="Updated")
  assert_eq(s2.placeholders().length(), 1)
  // Round-trips through serialize → parse.
  let re = @slide.Slide::parse(s2.serialize())
  assert_eq(re.placeholders().length(), 1)
  match re.title() {
    Some(AutoShape(sp)) => assert_eq(sp.placeholder.unwrap().ph_type, "title")
    _ => fail("expected a title AutoShape after round-trip")
  }
}

///|
test "Slide::with_placeholder: distinct idx coexist (two content areas)" {
  let s = @slide.Slide::parse(slide_with_bg(""))
    .with_placeholder(@slide.PlaceholderType::Body, 1, text="Left")
    .with_placeholder(@slide.PlaceholderType::Body, 2, text="Right")
  assert_eq(s.placeholders().length(), 2)
}

///|
test "Slide::with_placeholder: no text yields an empty-body placeholder" {
  let s = @slide.Slide::parse(slide_with_bg("")).with_placeholder(
    @slide.PlaceholderType::Title,
    0,
  )
  assert_true(s.title() is Some(_))
  // Survives a round-trip with the placeholder metadata intact.
  let re = @slide.Slide::parse(s.serialize())
  assert_true(re.title() is Some(_))
}
