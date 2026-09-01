// Font resolution: theme references and per-script fallback.

///|
/// A collection shaped like the ones Office writes: an empty `ea` slot with
/// the real CJK faces carried by `<a:font script="…">` entries instead.
fn office_shaped_collection() -> @theme.FontCollection {
  {
    latin: "Calibri",
    ea: "",
    cs: "",
    scripts: [
      { script: "Jpan", typeface: "ＭＳ Ｐゴシック", },
      { script: "Hans", typeface: "宋体", },
      { script: "Arab", typeface: "Times New Roman", },
    ],
    extension: [],
  }
}

///|
fn scheme_of(
  major : @theme.FontCollection,
  minor : @theme.FontCollection,
) -> @theme.FontScheme {
  { name: "Test", major_font: major, minor_font: minor, extension: [], }
}

///|
test "ThemeFontRef round-trips all six references" {
  let all = [
    @theme.ThemeFontRef::MajorLatin,
    @theme.ThemeFontRef::MajorEastAsian,
    @theme.ThemeFontRef::MajorComplexScript,
    @theme.ThemeFontRef::MinorLatin,
    @theme.ThemeFontRef::MinorEastAsian,
    @theme.ThemeFontRef::MinorComplexScript,
  ]
  for r in all {
    assert_true(@theme.ThemeFontRef::from_xml(r.to_xml()) == Some(r))
  }
  assert_eq(@theme.ThemeFontRef::MinorEastAsian.to_xml(), "+mn-ea")
}

///|
test "ThemeFontRef: a literal typeface is not a reference" {
  assert_true(@theme.ThemeFontRef::from_xml("Calibri") is None)
  assert_true(@theme.ThemeFontRef::from_xml("") is None)
  // Close but not one of the six.
  assert_true(@theme.ThemeFontRef::from_xml("+mn-xx") is None)
}

///|
test "FontScheme::resolve_typeface follows references and passes literals" {
  let scheme = scheme_of(
    {
      latin: "Calibri Light",
      ea: "Yu Gothic",
      cs: "",
      scripts: [],
      extension: [],
    },
    { latin: "Calibri", ea: "Meiryo", cs: "Arial", scripts: [], extension: [], },
  )
  assert_eq(scheme.resolve_typeface("+mj-lt"), "Calibri Light")
  assert_eq(scheme.resolve_typeface("+mj-ea"), "Yu Gothic")
  assert_eq(scheme.resolve_typeface("+mn-lt"), "Calibri")
  assert_eq(scheme.resolve_typeface("+mn-ea"), "Meiryo")
  assert_eq(scheme.resolve_typeface("+mn-cs"), "Arial")
  // Literals pass straight through.
  assert_eq(scheme.resolve_typeface("Meiryo UI"), "Meiryo UI")
}

///|
test "ScriptSlot::of_script splits east-asian from complex from latin" {
  for s in ["Jpan", "Hans", "Hant", "Hang", "Bopo"] {
    assert_true(@theme.ScriptSlot::of_script(s) is EastAsianSlot)
  }
  for s in ["Arab", "Hebr", "Thai", "Deva", "Tibt"] {
    assert_true(@theme.ScriptSlot::of_script(s) is ComplexScriptSlot)
  }
  // Alphabetic scripts and unknown tags both use the Latin slot.
  for s in ["Cyrl", "Grek", "Zzzz"] {
    assert_true(@theme.ScriptSlot::of_script(s) is LatinSlot)
  }
}

///|
test "typeface_for_script: a script entry beats the slot" {
  let c = office_shaped_collection()
  assert_eq(c.typeface_for_script("Jpan"), "ＭＳ Ｐゴシック")
  assert_eq(c.typeface_for_script("Hans"), "宋体")
  assert_eq(c.typeface_for_script("Arab"), "Times New Roman")
}

///|
test "typeface_for_script: an empty slot falls back to latin, not to nothing" {
  // This is the Office default shape — `<a:ea typeface=""/>` — so a script
  // with no entry must not resolve to the empty string.
  let c = office_shaped_collection()
  assert_eq(c.typeface_for_script("Hang"), "Calibri")
  assert_eq(c.typeface_for_script("Cyrl"), "Calibri")
}

///|
test "typeface_for_script: a populated slot serves scripts with no entry" {
  let c : @theme.FontCollection = {
    latin: "Calibri",
    ea: "Meiryo",
    cs: "Arial",
    scripts: [],
    extension: [],
  }
  assert_eq(c.typeface_for_script("Jpan"), "Meiryo")
  assert_eq(c.typeface_for_script("Hang"), "Meiryo")
  assert_eq(c.typeface_for_script("Arab"), "Arial")
  assert_eq(c.typeface_for_script("Grek"), "Calibri")
}
