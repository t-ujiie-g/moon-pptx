///|
test "RgbColor::new accessors" {
  let c = @units.RgbColor::new(255, 128, 0)
  assert_eq(c.r, 255)
  assert_eq(c.g, 128)
  assert_eq(c.b, 0)
}

///|
test "parse_hex / to_hex round trip" {
  let cases = [
    "FF0000", "00FF00", "0000FF", "808080", "000000", "FFFFFF", "1A2B3C",
  ]
  for hex in cases {
    let c = @units.RgbColor::parse_hex(hex)
    assert_eq(c.to_hex(), hex)
  }
}

///|
test "parse_hex accepts both # prefix and lowercase" {
  let a = @units.RgbColor::parse_hex("#ff8800")
  assert_eq(a, @units.RgbColor::new(255, 136, 0))
  assert_eq(a.to_hex(), "FF8800")
  let b = @units.RgbColor::parse_hex("ff8800")
  assert_eq(a, b)
}

///|
test "parse_hex rejects malformed input" {
  // wrong length
  for bad in ["", "F", "FF", "FFFF", "FFFFF", "FFFFFFF", "##FF0000"] {
    let result = try? @units.RgbColor::parse_hex(bad)
    assert_true(result is Err(@units.UnitsError::InvalidHexColor(_)))
  }
  // non-hex digit
  for bad in ["GGGGGG", "FF00ZZ", "12345G"] {
    let result = try? @units.RgbColor::parse_hex(bad)
    assert_true(result is Err(@units.UnitsError::InvalidHexColor(_)))
  }
}

///|
test "to_hex always produces uppercase, no #" {
  assert_eq(@units.RgbColor::new(0, 0, 0).to_hex(), "000000")
  assert_eq(@units.RgbColor::new(255, 255, 255).to_hex(), "FFFFFF")
  assert_eq(@units.RgbColor::new(10, 11, 12).to_hex(), "0A0B0C")
}
