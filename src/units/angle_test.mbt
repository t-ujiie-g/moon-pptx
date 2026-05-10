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
