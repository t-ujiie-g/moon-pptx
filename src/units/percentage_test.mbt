///|
test "Percentage round trip via OOXML integer" {
  let p = @units.Percentage(50.0)
  assert_eq(p.to_ooxml(), 50_000)
  assert_eq(@units.Percentage::from_ooxml(50_000).value(), 50.0)
}

///|
test "Percentage scale and constants" {
  assert_eq(@units.ooxml_per_percent, 1000)
  assert_eq(@units.Percentage(0.0).to_ooxml(), 0)
  assert_eq(@units.Percentage(100.0).to_ooxml(), 100_000)
  assert_eq(@units.Percentage(0.5).to_ooxml(), 500)
}

///|
test "Percentage can be negative (e.g. tint -10%)" {
  assert_eq(@units.Percentage(-10.0).to_ooxml(), -10_000)
}
