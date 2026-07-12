// TableStylePreset tests.

///|
test "TableStylePreset: gallery spot-checks against MS-OE376" {
  // PowerPoint's insert-table default.
  assert_eq(
    @slide.TableStylePreset::MediumStyle2Accent1.guid(),
    "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}",
  )
  assert_eq(
    @slide.TableStylePreset::NoStyleNoGrid.guid(),
    "{2D5ABB26-0587-4C30-8999-92F81FD0307C}",
  )
  assert_eq(
    @slide.TableStylePreset::LightStyle1.guid(),
    "{9D7B26C5-4107-4FEC-AEDC-1716B250A1EF}",
  )
  assert_eq(
    @slide.TableStylePreset::DarkStyle2Accent5And6.guid(),
    "{46F890A9-2807-4EBB-B81D-B2AA78EC7F39}",
  )
}

///|
/// Every built-in style, for the exhaustive checks below.
fn all_table_style_presets() -> Array[@slide.TableStylePreset] {
  [
    NoStyleNoGrid,
    ThemedStyle1Accent1,
    ThemedStyle1Accent2,
    ThemedStyle1Accent3,
    ThemedStyle1Accent4,
    ThemedStyle1Accent5,
    ThemedStyle1Accent6,
    NoStyleTableGrid,
    ThemedStyle2Accent1,
    ThemedStyle2Accent2,
    ThemedStyle2Accent3,
    ThemedStyle2Accent4,
    ThemedStyle2Accent5,
    ThemedStyle2Accent6,
    LightStyle1,
    LightStyle1Accent1,
    LightStyle1Accent2,
    LightStyle1Accent3,
    LightStyle1Accent4,
    LightStyle1Accent5,
    LightStyle1Accent6,
    LightStyle2,
    LightStyle2Accent1,
    LightStyle2Accent2,
    LightStyle2Accent3,
    LightStyle2Accent4,
    LightStyle2Accent5,
    LightStyle2Accent6,
    LightStyle3,
    LightStyle3Accent1,
    LightStyle3Accent2,
    LightStyle3Accent3,
    LightStyle3Accent4,
    LightStyle3Accent5,
    LightStyle3Accent6,
    MediumStyle1,
    MediumStyle1Accent1,
    MediumStyle1Accent2,
    MediumStyle1Accent3,
    MediumStyle1Accent4,
    MediumStyle1Accent5,
    MediumStyle1Accent6,
    MediumStyle2,
    MediumStyle2Accent1,
    MediumStyle2Accent2,
    MediumStyle2Accent3,
    MediumStyle2Accent4,
    MediumStyle2Accent5,
    MediumStyle2Accent6,
    MediumStyle3,
    MediumStyle3Accent1,
    MediumStyle3Accent2,
    MediumStyle3Accent3,
    MediumStyle3Accent4,
    MediumStyle3Accent5,
    MediumStyle3Accent6,
    MediumStyle4,
    MediumStyle4Accent1,
    MediumStyle4Accent2,
    MediumStyle4Accent3,
    MediumStyle4Accent4,
    MediumStyle4Accent5,
    MediumStyle4Accent6,
    DarkStyle1,
    DarkStyle1Accent1,
    DarkStyle1Accent2,
    DarkStyle1Accent3,
    DarkStyle1Accent4,
    DarkStyle1Accent5,
    DarkStyle1Accent6,
    DarkStyle2,
    DarkStyle2Accent1And2,
    DarkStyle2Accent3And4,
    DarkStyle2Accent5And6,
  ]
}

///|
test "TableStylePreset: 74 styles, distinct well-formed GUIDs" {
  let presets = all_table_style_presets()
  assert_eq(presets.length(), 74)
  let seen : Array[String] = []
  for p in presets {
    let g = p.guid()
    assert_eq(g.length(), 38)
    assert_true(g.has_prefix("{") && g.has_suffix("}"))
    assert_true(!seen.contains(g))
    seen.push(g)
  }
}

///|
test "TableProperties::with_style: sets the id, keeps everything else" {
  let p = @slide.TableProperties::default()
  let styled = { ..p, first_row: Some(true) }.with_style(LightStyle2Accent3)
  assert_eq(
    styled.table_style_id.unwrap(),
    @slide.TableStylePreset::LightStyle2Accent3.guid(),
  )
  assert_true(styled.first_row == Some(true))
  assert_true(styled.fill is None)
}

///|
test "Table::with_style: default flags on, existing properties kept" {
  let t = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=@units.Emu(914400L),
    row_height=@units.Emu(457200L),
  )
  let styled = t.with_style(MediumStyle2Accent1)
  let p = styled.properties.unwrap()
  assert_eq(p.table_style_id.unwrap(), "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}")
  assert_true(p.first_row == Some(true))
  assert_true(p.band_row == Some(true))
  // Flags are opt-outable.
  let plain = t.with_style(MediumStyle2Accent1, first_row=false, band_row=false)
  assert_true(plain.properties.unwrap().first_row == Some(false))
  // The original table is untouched (immutable builder).
  assert_true(t.properties.unwrap().table_style_id is None)
}

///|
test "Table::with_style: styled table survives serialize -> reparse" {
  let t = @slide.Table::of_grid(
    rows=1,
    cols=1,
    col_width=@units.Emu(914400L),
    row_height=@units.Emu(457200L),
  ).with_style(DarkStyle1Accent3)
  let gf = @slide.GraphicFrame::of_table(
    7,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914400L),
    @units.Emu(457200L),
    t,
  )
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(fixture_bytes(base_xml))
  let s = base.with_shape(@slide.GraphicFrame(gf))
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    GraphicFrame(parsed_gf) =>
      match parsed_gf.content {
        TableContent(parsed_t) => {
          let p = parsed_t.properties.unwrap()
          assert_eq(
            p.table_style_id.unwrap(),
            @slide.TableStylePreset::DarkStyle1Accent3.guid(),
          )
          assert_true(p.first_row == Some(true))
          assert_true(p.band_row == Some(true))
        }
        _ => fail("expected TableContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "Table::with_style: creates properties when the table has none" {
  let bare : @slide.Table = {
    properties: None,
    grid: [@units.Emu(914400L)],
    rows: [],
    extension: [],
  }
  let styled = bare.with_style(NoStyleTableGrid)
  let p = styled.properties.unwrap()
  assert_eq(
    p.table_style_id.unwrap(),
    @slide.TableStylePreset::NoStyleTableGrid.guid(),
  )
  assert_true(p.first_row == Some(true))
}
