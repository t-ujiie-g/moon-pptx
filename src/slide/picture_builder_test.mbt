// Tests for the typed picture builder state machine.
//
// The compile-time guarantees (no second `with_crop`; no `with_effects`
// after `build`) are enforced by the type system and so cannot be
// exercised at runtime — these tests cover the *values* each stage
// produces and that a fully-built picture round-trips.

///|
fn thin_stroke() -> @oxml.Stroke {
  {
    width: Some(@units.Emu(12700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: None,
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
}

///|
fn empty_effects() -> @oxml.EffectList {
  {
    blur: None,
    glow: None,
    inner_shadow: None,
    outer_shadow: None,
    preset_shadow: None,
    reflection: None,
    soft_edge: None,
    extension: [],
  }
}

///|
fn pic_builder() -> @slide.PictureUncropped {
  @slide.Picture::builder(
    5,
    "Pic",
    "rId2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
}

// --- build at each stage ---

///|
test "Picture::builder: build with no crop/effects equals of_image" {
  let built = pic_builder().build()
  let flat = @slide.Picture::of_image(
    5,
    "Pic",
    "rId2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(built == flat)
}

///|
test "Picture::builder: with_crop sets the source rectangle" {
  let pic = pic_builder()
    .with_crop(left=@units.Percentage(10.0), right=@units.Percentage(5.0))
    .build()
  match pic.blip_fill.src_rect {
    Some(rect) => {
      assert_true(rect.left == @units.Percentage(10.0))
      assert_true(rect.right == @units.Percentage(5.0))
    }
    None => fail("expected a crop rectangle")
  }
}

///|
test "Picture::builder: with_effects sets outline + effect list" {
  let stroke = thin_stroke()
  let effects = empty_effects()
  let pic = pic_builder().with_effects(outline=stroke, effects~).build()
  assert_true(pic.stroke == Some(stroke))
  assert_true(pic.effects == Some(effects))
}

///|
test "Picture::builder: with_effects leaves omitted fields unset" {
  let pic = pic_builder().with_effects(outline=thin_stroke()).build()
  assert_true(pic.stroke is Some(_))
  assert_true(pic.effects is None)
}

///|
test "Picture::builder: crop then effects keeps both" {
  let pic = pic_builder()
    .with_crop(top=@units.Percentage(8.0))
    .with_effects(outline=thin_stroke())
    .build()
  assert_true(pic.blip_fill.src_rect is Some(_))
  assert_true(pic.stroke is Some(_))
}

///|
test "Picture::builder: build straight after crop (no effects)" {
  let pic = pic_builder().with_crop(bottom=@units.Percentage(3.0)).build()
  assert_true(pic.blip_fill.src_rect is Some(_))
  assert_true(pic.stroke is None)
  assert_true(pic.effects is None)
}

// --- round-trip ---

///|
test "Picture::builder: built picture round-trips through a slide" {
  let pic = pic_builder()
    .with_crop(left=@units.Percentage(5.0), top=@units.Percentage(5.0))
    .with_effects(outline=thin_stroke())
    .build()
  let reparsed = @slide.Slide::parse(slide_of_picture(pic).serialize())
  match reparsed.shapes[0] {
    Picture(p) => {
      assert_true(p.blip_fill.src_rect is Some(_))
      assert_true(p.stroke is Some(_))
    }
    _ => fail("expected a picture shape")
  }
}
