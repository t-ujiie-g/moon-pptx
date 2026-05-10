///|
test "ThemeColor xml round trip for every variant" {
  let names = [
    "bg1", "bg2", "tx1", "tx2", "dk1", "dk2", "lt1", "lt2", "accent1", "accent2",
    "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink", "phClr",
  ]
  for n in names {
    let parsed = @units.ThemeColor::from_xml(n)
    assert_eq(parsed.to_xml(), n)
  }
}

///|
test "ThemeColor::from_xml rejects unknown names" {
  for bad in ["", "BG1", "accent7", "accent10", "bgX", "purple"] {
    let result = try? @units.ThemeColor::from_xml(bad)
    assert_true(result is Err(@units.UnitsError::UnknownSchemeColor(_)))
  }
}

///|
test "ThemeColor variants are distinct" {
  // A handful of equality checks confirm the enum tags are not collapsed.
  assert_true(@units.ThemeColor::Accent1 != @units.ThemeColor::Accent2)
  assert_true(@units.ThemeColor::Bg1 != @units.ThemeColor::Tx1)
  assert_true(@units.ThemeColor::Dk1 != @units.ThemeColor::Lt1)
  assert_true(@units.ThemeColor::Hlink != @units.ThemeColor::FolHlink)
}

///|
test "SchemeColor builder is immutable" {
  let base = @units.SchemeColor::new(@units.ThemeColor::Accent1)
  assert_eq(base.transforms.length(), 0)
  let lighter = base.with_transform(
    @units.ColorTransform::Tint(@units.Percentage(40.0)),
  )
  // original unchanged
  assert_eq(base.transforms.length(), 0)
  assert_eq(lighter.transforms.length(), 1)
  // chained build
  let chained = lighter.with_transform(
    @units.ColorTransform::LumMod(@units.Percentage(75.0)),
  )
  assert_eq(chained.transforms.length(), 2)
  assert_eq(lighter.transforms.length(), 1)
}

///|
test "SchemeColor preserves transform order" {
  let c = @units.SchemeColor::new(@units.ThemeColor::Accent3)
    .with_transform(@units.ColorTransform::Tint(@units.Percentage(20.0)))
    .with_transform(@units.ColorTransform::Alpha(@units.Percentage(80.0)))
    .with_transform(@units.ColorTransform::SatMod(@units.Percentage(150.0)))
  assert_eq(c.transforms.length(), 3)
  assert_true(c.transforms[0] is @units.ColorTransform::Tint(_))
  assert_true(c.transforms[1] is @units.ColorTransform::Alpha(_))
  assert_true(c.transforms[2] is @units.ColorTransform::SatMod(_))
}
