// Inheritance resolver tests.
//
// We assemble a small theme + master + layout fixture by hand (rather than
// reusing the parser test fixtures) so each test asserts the exact values
// it depends on.

///|
fn fixed_color_mapping(
  bg1 : @units.ThemeColor,
  tx1 : @units.ThemeColor,
) -> @slide_master.ColorMapping {
  // Most slots are accent1/etc — only the two we vary matter for the
  // tests; the remaining values are just spec-valid filler.
  {
    bg1,
    tx1,
    bg2: @units.ThemeColor::Lt2,
    tx2: @units.ThemeColor::Dk2,
    accent1: @units.ThemeColor::Accent1,
    accent2: @units.ThemeColor::Accent2,
    accent3: @units.ThemeColor::Accent3,
    accent4: @units.ThemeColor::Accent4,
    accent5: @units.ThemeColor::Accent5,
    accent6: @units.ThemeColor::Accent6,
    hlink: @units.ThemeColor::Hlink,
    fol_hlink: @units.ThemeColor::FolHlink,
  }
}

///|
fn srgb(hex : String) -> @theme.ColorChoice raise @units.UnitsError {
  @theme.ColorChoice::Srgb(@units.RgbColor::parse_hex(hex))
}

///|
fn fixture_scheme() -> @theme.ColorScheme raise @units.UnitsError {
  // Twelve distinct colours so every slot resolves to a unique RGB.
  {
    name: "Test",
    dk1: srgb("000001"),
    lt1: srgb("FFFFF1"),
    dk2: srgb("000002"),
    lt2: srgb("FFFFF2"),
    accent1: srgb("AAAA01"),
    accent2: srgb("AAAA02"),
    accent3: srgb("AAAA03"),
    accent4: srgb("AAAA04"),
    accent5: srgb("AAAA05"),
    accent6: srgb("AAAA06"),
    hlink: srgb("BBBB01"),
    fol_hlink: srgb("BBBB02"),
  }
}

///|
fn fixture_master() -> @slide_master.SlideMaster {
  // Master maps bg1=lt1 (the standard PPT default), tx1=dk1.
  {
    color_mapping: fixed_color_mapping(
      @units.ThemeColor::Lt1,
      @units.ThemeColor::Dk1,
    ),
    layout_refs: [],
  }
}

///|
fn layout_inheriting() -> @slide_master.SlideLayout {
  {
    name: "Inherits",
    layout_type: @slide_master.SlideLayoutType::Title,
    clr_map_override: @slide_master.ClrMapOverride::MasterMapping,
  }
}

///|
fn layout_overriding() -> @slide_master.SlideLayout {
  // Layout flips bg1=dk1 (dark slides), tx1=lt1.
  let cm = fixed_color_mapping(@units.ThemeColor::Dk1, @units.ThemeColor::Lt1)
  {
    name: "Override",
    layout_type: @slide_master.SlideLayoutType::Title,
    clr_map_override: @slide_master.ClrMapOverride::Override(cm),
  }
}

// --- effective_color_mapping ---

///|
test "MasterMapping → master's clrMap" {
  let cm = @slide_master.effective_color_mapping(
    fixture_master(),
    layout_inheriting(),
  )
  assert_true(cm.bg1 is @units.ThemeColor::Lt1)
  assert_true(cm.tx1 is @units.ThemeColor::Dk1)
}

///|
test "Override → layout's explicit mapping" {
  let cm = @slide_master.effective_color_mapping(
    fixture_master(),
    layout_overriding(),
  )
  assert_true(cm.bg1 is @units.ThemeColor::Dk1)
  assert_true(cm.tx1 is @units.ThemeColor::Lt1)
}

// --- resolve_slide_color ---

///|
test "resolve_slide_color: through inherited mapping then theme" {
  // Slide reference bg1, master maps bg1=lt1, theme lt1 = #FFFFF1.
  let result = @slide_master.resolve_slide_color(
    @units.ThemeColor::Bg1,
    fixture_master(),
    layout_inheriting(),
    fixture_scheme(),
  )
  match result.unwrap() {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "FFFFF1")
    _ => fail("expected Srgb")
  }
}

///|
test "resolve_slide_color: layout override takes precedence" {
  // Same slide reference bg1, but the layout overrides to map bg1=dk1.
  // Theme dk1 = #000001.
  let result = @slide_master.resolve_slide_color(
    @units.ThemeColor::Bg1,
    fixture_master(),
    layout_overriding(),
    fixture_scheme(),
  )
  match result.unwrap() {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "000001")
    _ => fail("expected Srgb")
  }
}

///|
test "resolve_slide_color: accent passthrough" {
  // accent3 → accent3 (identity in fixture mapping) → theme accent3
  let result = @slide_master.resolve_slide_color(
    @units.ThemeColor::Accent3,
    fixture_master(),
    layout_inheriting(),
    fixture_scheme(),
  )
  match result.unwrap() {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "AAAA03")
    _ => fail("expected Srgb")
  }
}

///|
test "resolve_slide_color: master-level slot has no slide mapping" {
  // Dk1/Lt1/Dk2/Lt2/PhClr aren't legal mapping inputs, so resolution returns None.
  let none = @slide_master.resolve_slide_color(
    @units.ThemeColor::Dk1,
    fixture_master(),
    layout_inheriting(),
    fixture_scheme(),
  )
  assert_true(none is None)
}

// --- lookup_theme_slot ---

///|
test "lookup_theme_slot: bg1 and lt1 resolve to the same slot" {
  let scheme = fixture_scheme()
  let bg1_choice = @slide_master.lookup_theme_slot(
    @units.ThemeColor::Bg1,
    scheme,
  )
  let lt1_choice = @slide_master.lookup_theme_slot(
    @units.ThemeColor::Lt1,
    scheme,
  )
  assert_eq(bg1_choice, lt1_choice)
}

///|
test "lookup_theme_slot: tx1 and dk1 resolve to the same slot" {
  let scheme = fixture_scheme()
  let tx1_choice = @slide_master.lookup_theme_slot(
    @units.ThemeColor::Tx1,
    scheme,
  )
  let dk1_choice = @slide_master.lookup_theme_slot(
    @units.ThemeColor::Dk1,
    scheme,
  )
  assert_eq(tx1_choice, dk1_choice)
}

///|
test "lookup_theme_slot: each accent maps distinctly" {
  let s = fixture_scheme()
  // Spot-check: accent1 != accent2, accent5 != accent6
  assert_true(
    @slide_master.lookup_theme_slot(@units.ThemeColor::Accent1, s) !=
    @slide_master.lookup_theme_slot(@units.ThemeColor::Accent2, s),
  )
  assert_true(
    @slide_master.lookup_theme_slot(@units.ThemeColor::Accent5, s) !=
    @slide_master.lookup_theme_slot(@units.ThemeColor::Accent6, s),
  )
}
