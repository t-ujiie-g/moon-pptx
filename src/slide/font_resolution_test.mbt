// Run → theme font resolution and the per-script builders.

///|
/// The shape Office actually writes: an empty `ea` slot, with the CJK faces
/// carried by `<a:font script="…">` entries.
fn office_scheme() -> @theme.FontScheme {
  let minor : @theme.FontCollection = {
    latin: "Calibri",
    ea: "",
    cs: "",
    scripts: [
      { script: "Jpan", typeface: "ＭＳ Ｐゴシック", },
      { script: "Arab", typeface: "Times New Roman", },
    ],
    extension: [],
  }
  let major : @theme.FontCollection = {
    latin: "Calibri Light",
    ea: "",
    cs: "",
    scripts: [{ script: "Jpan", typeface: "ＭＳ Ｐ明朝", }],
    extension: [],
  }
  { name: "Office", major_font: major, minor_font: minor, extension: [], }
}

///|
test "resolve_run_fonts: a run with no fonts takes the theme's" {
  let r = @slide.resolve_run_fonts(
    @slide.RunProperties::default(),
    office_scheme(),
  )
  assert_eq(r.latin, "Calibri")
  assert_eq(r.east_asian, "")
  assert_eq(r.complex_script, "")
}

///|
test "resolve_run_fonts: major picks the heading collection" {
  let r = @slide.resolve_run_fonts(
    @slide.RunProperties::default(),
    office_scheme(),
    major=true,
  )
  assert_eq(r.latin, "Calibri Light")
}

///|
test "resolve_run_fonts: theme references are followed, literals are not" {
  // This is what a parsed deck looks like: `latin` holds "+mn-lt", not a font.
  let themed = @slide.RunProperties::default()
    .with_font("+mn-lt")
    .with_east_asian_font("+mj-lt")
  let r = @slide.resolve_run_fonts(themed, office_scheme())
  assert_eq(r.latin, "Calibri")
  assert_eq(r.east_asian, "Calibri Light")
  let literal = @slide.RunProperties::default().with_font("Meiryo UI")
  assert_eq(
    @slide.resolve_run_fonts(literal, office_scheme()).latin,
    "Meiryo UI",
  )
}

///|
test "resolve_run_font_for_script: Japanese resolves through the script entry" {
  // The whole point of G2 — the theme's `ea` slot is empty, so nothing on the
  // run or in `ea` names the font this text actually renders with.
  let scheme = office_scheme()
  let plain = @slide.RunProperties::default()
  assert_eq(
    @slide.resolve_run_font_for_script(plain, scheme, "Jpan"),
    "ＭＳ Ｐゴシック",
  )
  assert_eq(
    @slide.resolve_run_font_for_script(plain, scheme, "Jpan", major=true),
    "ＭＳ Ｐ明朝",
  )
  assert_eq(
    @slide.resolve_run_font_for_script(plain, scheme, "Arab"),
    "Times New Roman",
  )
  // A script with neither an entry nor a slot falls back to latin.
  assert_eq(
    @slide.resolve_run_font_for_script(plain, scheme, "Hang"),
    "Calibri",
  )
}

///|
test "resolve_run_font_for_script: an explicit run font overrides the theme" {
  let rp = @slide.RunProperties::default().with_east_asian_font("Meiryo")
  assert_eq(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Jpan"),
    "Meiryo",
  )
  // …but a Latin script still uses the Latin slot, not the override.
  assert_eq(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Grek"),
    "Calibri",
  )
}

///|
test "resolve_run_font_for_script: a reference resolving to empty keeps falling back" {
  // `+mn-ea` points at the theme's empty `ea`; the script entry must still win.
  let rp = @slide.RunProperties::default().with_east_asian_font("+mn-ea")
  assert_eq(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Jpan"),
    "ＭＳ Ｐゴシック",
  )
}

// --- builders ---

///|
test "with_east_asian_font / with_complex_script_font set only their slot" {
  let rp = @slide.RunProperties::default()
    .with_font("Calibri")
    .with_east_asian_font("Meiryo")
    .with_complex_script_font("Arial")
  assert_eq(rp.latin, Some("Calibri"))
  assert_eq(rp.east_asian, Some("Meiryo"))
  assert_eq(rp.complex_script, Some("Arial"))
}

///|
test "with_font_for_all_scripts sets all three slots" {
  let rp = @slide.RunProperties::default().with_font_for_all_scripts("Meiryo")
  assert_eq(rp.latin, Some("Meiryo"))
  assert_eq(rp.east_asian, Some("Meiryo"))
  assert_eq(rp.complex_script, Some("Meiryo"))
  // And that is enough for CJK to render in it whatever the theme says.
  assert_eq(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Jpan"),
    "Meiryo",
  )
}
