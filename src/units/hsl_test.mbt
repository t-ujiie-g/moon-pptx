///|
fn approx_eq(a : Double, b : Double, eps : Double) -> Bool {
  (a - b).abs() < eps
}

///|
fn rgb_close(a : @units.RgbColor, b : @units.RgbColor, tol : Int) -> Bool {
  (a.r - b.r).abs() <= tol &&
  (a.g - b.g).abs() <= tol &&
  (a.b - b.b).abs() <= tol
}

///|
test "primary colors HSL -> RGB" {
  assert_eq(
    @units.HslColor::new(0.0, 100.0, 50.0).to_rgb(),
    @units.RgbColor::new(255, 0, 0),
  )
  assert_eq(
    @units.HslColor::new(120.0, 100.0, 50.0).to_rgb(),
    @units.RgbColor::new(0, 255, 0),
  )
  assert_eq(
    @units.HslColor::new(240.0, 100.0, 50.0).to_rgb(),
    @units.RgbColor::new(0, 0, 255),
  )
}

///|
test "grayscale HSL -> RGB" {
  assert_eq(
    @units.HslColor::new(0.0, 0.0, 0.0).to_rgb(),
    @units.RgbColor::new(0, 0, 0),
  )
  assert_eq(
    @units.HslColor::new(0.0, 0.0, 100.0).to_rgb(),
    @units.RgbColor::new(255, 255, 255),
  )
  // 50% gray rounds to 128
  assert_eq(
    @units.HslColor::new(0.0, 0.0, 50.0).to_rgb(),
    @units.RgbColor::new(128, 128, 128),
  )
}

///|
test "primary colors RGB -> HSL" {
  let red_hsl = @units.RgbColor::new(255, 0, 0).to_hsl()
  assert_true(approx_eq(red_hsl.hue, 0.0, 1.0e-9))
  assert_true(approx_eq(red_hsl.saturation, 100.0, 1.0e-9))
  assert_true(approx_eq(red_hsl.lightness, 50.0, 1.0e-9))
  let green_hsl = @units.RgbColor::new(0, 255, 0).to_hsl()
  assert_true(approx_eq(green_hsl.hue, 120.0, 1.0e-9))
  let blue_hsl = @units.RgbColor::new(0, 0, 255).to_hsl()
  assert_true(approx_eq(blue_hsl.hue, 240.0, 1.0e-9))
}

///|
test "RGB -> HSL -> RGB round trip is within ±1 per channel" {
  // Sweeping a representative set; within ±1 is acceptable for 8-bit channels
  // because the HSL pipeline goes through floating point and back.
  let cases = [
    @units.RgbColor::new(255, 0, 0),
    @units.RgbColor::new(0, 255, 0),
    @units.RgbColor::new(0, 0, 255),
    @units.RgbColor::new(255, 255, 0),
    @units.RgbColor::new(0, 255, 255),
    @units.RgbColor::new(255, 0, 255),
    @units.RgbColor::new(128, 64, 200),
    @units.RgbColor::new(17, 53, 119),
    @units.RgbColor::new(200, 100, 50),
  ]
  for c in cases {
    let round = c.to_hsl().to_rgb()
    assert_true(rgb_close(c, round, 1))
  }
}

///|
test "wrap_hue: HSL accepts out-of-range hue (e.g. -120 = 240)" {
  let a = @units.HslColor::new(-120.0, 100.0, 50.0).to_rgb()
  let b = @units.HslColor::new(240.0, 100.0, 50.0).to_rgb()
  assert_eq(a, b)
}
