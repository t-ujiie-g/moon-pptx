// Top-level smoke test for the units package.

///|
test "package exports compile" {
  let _ : @units.Emu = @units.Inch(1.0).to_emu()
  let _ : @units.Pt = @units.Emu(914_400L).to_pt()
  let _ : @units.Cm = @units.Emu(914_400L).to_cm()
}
