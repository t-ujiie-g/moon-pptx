// Conversions are tested against the OOXML reference table:
//   1 inch = 914_400 EMU = 72 pt = 2.54 cm
// Round-trip cases use exact powers of the conversion factors so Double
// imprecision does not show up.

///|
test "constants match OOXML reference table" {
  assert_eq(@units.emu_per_inch, 914_400L)
  assert_eq(@units.emu_per_pt, 12_700L)
  assert_eq(@units.emu_per_cm, 360_000L)
  // 1 inch = 72 pt
  assert_eq(@units.emu_per_inch, @units.emu_per_pt * 72L)
}

///|
test "Inch -> Emu" {
  assert_eq(@units.Inch(1.0).to_emu(), @units.Emu(914_400L))
  assert_eq(@units.Inch(0.5).to_emu(), @units.Emu(457_200L))
  assert_eq(@units.Inch(10.0).to_emu(), @units.Emu(9_144_000L))
}

///|
test "Pt -> Emu" {
  assert_eq(@units.Pt(72.0).to_emu(), @units.Emu(914_400L))
  assert_eq(@units.Pt(1.0).to_emu(), @units.Emu(12_700L))
  assert_eq(@units.Pt(36.0).to_emu(), @units.Emu(457_200L))
}

///|
test "Cm -> Emu" {
  assert_eq(@units.Cm(2.54).to_emu(), @units.Emu(914_400L))
  assert_eq(@units.Cm(1.0).to_emu(), @units.Emu(360_000L))
  assert_eq(@units.Cm(10.0).to_emu(), @units.Emu(3_600_000L))
}

///|
test "Emu -> Inch round trip" {
  let original = @units.Inch(1.5)
  let round = original.to_emu().to_inch()
  assert_true((round.value() - original.value()).abs() < 1.0e-9)
}

///|
test "Emu -> Pt round trip" {
  let original = @units.Pt(36.0)
  let round = original.to_emu().to_pt()
  assert_true((round.value() - original.value()).abs() < 1.0e-9)
}

///|
test "Emu -> Cm round trip" {
  let original = @units.Cm(2.54)
  let round = original.to_emu().to_cm()
  assert_true((round.value() - original.value()).abs() < 1.0e-9)
}

///|
test "Emu compare and equal" {
  let a = @units.Emu(100L)
  let b = @units.Emu(200L)
  assert_true(a < b)
  assert_eq(a, @units.Emu(100L))
  assert_true(a != b)
}

///|
test "Emu arithmetic" {
  let slide_w = @units.Inch(10.0).to_emu() // 9_144_000
  let slide_h = @units.Inch(7.5).to_emu() // 6_858_000
  let total = slide_w.add(slide_h)
  assert_eq(total, @units.Emu(16_002_000L))
  let diff = slide_w.sub(slide_h)
  assert_eq(diff, @units.Emu(2_286_000L))
  assert_eq(slide_w.neg(), @units.Emu(-9_144_000L))
}

///|
test "Emu does not overflow on slide-scale products" {
  // A 1920x1080 widescreen slide is ~12_192_000 x 6_858_000 EMU.
  // Their product (~8.36e13) overflows Int32 but fits in Int64.
  let w = @units.Emu(12_192_000L)
  let h = @units.Emu(6_858_000L)
  let area = w.value() * h.value()
  assert_true(area > 0L)
  assert_eq(area, 83_612_736_000_000L)
}
