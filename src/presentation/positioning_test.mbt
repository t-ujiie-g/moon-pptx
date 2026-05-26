// Tests for percentage / slide-extent positioning helpers (v0.2 C2).

///|
test "pct_w / pct_h on a fresh deck (4:3 default)" {
  let prs = @presentation.Presentation::new()
  // 4:3 defaults: 9_144_000 × 6_858_000 EMU.
  assert_eq(prs.pct_w(0.0), @units.Emu(0L))
  assert_eq(prs.pct_w(100.0), @units.Emu(9_144_000L))
  assert_eq(prs.pct_w(50.0), @units.Emu(4_572_000L))
  assert_eq(prs.pct_h(100.0), @units.Emu(6_858_000L))
  assert_eq(prs.pct_h(50.0), @units.Emu(3_429_000L))
}

///|
test "slide_w / slide_h on a fresh deck" {
  let prs = @presentation.Presentation::new()
  assert_eq(prs.slide_w(), @units.Emu(9_144_000L))
  assert_eq(prs.slide_h(), @units.Emu(6_858_000L))
}

///|
test "pct_w / pct_h follow slide-size changes" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen) // 12_192_000 × 6_858_000
  assert_eq(prs.pct_w(100.0), @units.Emu(12_192_000L))
  assert_eq(prs.pct_w(25.0), @units.Emu(3_048_000L))
  // Height unchanged for widescreen.
  assert_eq(prs.pct_h(100.0), @units.Emu(6_858_000L))
}

///|
test "pct_w / pct_h compose with shape builders" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // 10 % margin, full-bleed banner.
  let tb = @slide.AutoShape::textbox(
    2,
    "Banner",
    prs.pct_w(10.0),
    prs.pct_h(5.0),
    prs.pct_w(80.0),
    prs.pct_h(15.0),
    "Hello",
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(tb)))
  let s = prs.slides()[0]
  let auto = match s.shapes[0] {
    AutoShape(a) => a
    _ => fail("expected AutoShape")
  }
  let xfrm = auto.transform.unwrap()
  // For 4:3 defaults (9_144_000 × 6_858_000):
  //   10% × 9_144_000 = 914_400 ; 5% × 6_858_000 = 342_900
  //   80% × 9_144_000 = 7_315_200 ; 15% × 6_858_000 = 1_028_700
  assert_eq(xfrm.offset.x, @units.Emu(914_400L))
  assert_eq(xfrm.offset.y, @units.Emu(342_900L))
  assert_eq(xfrm.extent.cx, @units.Emu(7_315_200L))
  assert_eq(xfrm.extent.cy, @units.Emu(1_028_700L))
}
