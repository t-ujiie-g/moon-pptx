///|
test "Angle round trip via OOXML integer" {
  let a = @units.Angle(90.0)
  assert_eq(a.to_ooxml(), 5_400_000)
  assert_eq(@units.Angle::from_ooxml(5_400_000).degrees(), 90.0)
}

///|
test "Angle scale and constants" {
  assert_eq(@units.ooxml_per_degree, 60_000)
  assert_eq(@units.Angle(0.0).to_ooxml(), 0)
  assert_eq(@units.Angle(360.0).to_ooxml(), 21_600_000)
  assert_eq(@units.Angle(45.0).to_ooxml(), 2_700_000)
}

///|
test "Angle can be negative (counter-clockwise)" {
  assert_eq(@units.Angle(-90.0).to_ooxml(), -5_400_000)
}

///|
test "Angle::from_ooxml round-trips integers that are not whole degrees" {
  for n in [59, 61, 63, 118, 122, 750_000, 16_777_215] {
    assert_eq(@units.Angle::from_ooxml(n).to_ooxml(), n)
    assert_eq(@units.Angle::from_ooxml(-n).to_ooxml(), -n)
  }
}

///|
test "Angle::to_ooxml rounds to the nearest unit" {
  assert_eq(@units.Angle(12.5).to_ooxml(), 750_000)
  assert_eq(@units.Angle(1.0 / 60_000.0 * 0.6).to_ooxml(), 1)
  assert_eq(@units.Angle(1.0 / 60_000.0 * 0.4).to_ooxml(), 0)
}
