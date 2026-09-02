// Builder-side tests for the `<a:effectLst>` records. `effect_test.mbt`
// and `effect_writer_test.mbt` cover the parse and write directions; these
// cover constructing a list from scratch, which is what
// `PictureUncropped::with_effects` needs.

///|
/// Read an effect list back out of the XML `effect_to_xml` produced, so a
/// builder-made value can be checked against what the writer and parser
/// agree on.
fn reparse_effect_list(el : @oxml.EffectList) -> @oxml.EffectList raise {
  let r = @xml.XmlReader::new(effect_to_xml(el))
  let _ = r.next() catch {
    _ => raise @oxml.EffectError::MalformedEffect("wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.EffectError::MalformedEffect("wrapper inner failed")
    }
    match ev {
      Some(StartElement(_, _)) => return @oxml.parse_effect_list(r)
      Some(EndElement(_)) =>
        raise @oxml.EffectError::MalformedEffect("empty wrapper")
      Some(_) => ()
      None => raise @oxml.EffectError::MalformedEffect("unexpected end")
    }
  }
  raise @oxml.EffectError::MalformedEffect("unreachable")
}

///|
test "Blur / Glow / SoftEdge constructors set their fields" {
  let blur = @oxml.Blur::new(@units.Emu(50_800L))
  assert_eq(blur.rad, @units.Emu(50_800L))
  assert_true(blur.grow is None)
  assert_eq(@oxml.Blur::new(@units.Emu(1L), grow=true).grow, Some(true))
  let red = @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0x00, 0x00))
  let glow = @oxml.Glow::new(@units.Emu(63_500L), red)
  assert_eq(glow.rad, @units.Emu(63_500L))
  assert_true(glow.color == red)
  assert_eq(@oxml.SoftEdge::new(@units.Emu(12_700L)).rad, @units.Emu(12_700L))
}

///|
test "InnerShadow / PresetShadow constructors set every required attribute" {
  let black = @oxml.Color::srgb(@units.RgbColor::new(0, 0, 0))
  let inner = @oxml.InnerShadow::new(
    blur_rad=@units.Emu(50_800L),
    dist=@units.Emu(25_400L),
    dir=@units.Angle::from_ooxml(2_700_000),
    color=black,
  )
  assert_eq(inner.blur_rad, @units.Emu(50_800L))
  assert_eq(inner.dist, @units.Emu(25_400L))
  assert_eq(inner.dir.to_ooxml(), 2_700_000)
  let preset = @oxml.PresetShadow::new(
    "shdw4",
    dist=@units.Emu(38_100L),
    dir=@units.Angle::from_ooxml(5_400_000),
    color=black,
  )
  assert_eq(preset.preset, "shdw4")
  assert_eq(preset.dist, @units.Emu(38_100L))
  assert_eq(preset.dir.to_ooxml(), 5_400_000)
}

///|
test "OuterShadow::new leaves the optionals unset; with_* fill them" {
  let black = @oxml.Color::srgb(@units.RgbColor::new(0, 0, 0))
  let base = @oxml.OuterShadow::new(
    blur_rad=@units.Emu(50_800L),
    dist=@units.Emu(25_400L),
    dir=@units.Angle::from_ooxml(2_700_000),
    color=black,
  )
  assert_true(base.sx is None && base.kx is None)
  assert_true(base.alignment is None && base.rotate_with_shape is None)
  let full = base
    .with_scale(sx=@units.Percentage(90.0), sy=@units.Percentage(80.0))
    .with_skew(
      kx=@units.Angle::from_ooxml(60_000),
      ky=@units.Angle::from_ooxml(120_000),
    )
    .with_alignment(RectBottomLeft)
    .with_rotate_with_shape(false)
  assert_eq(full.sx, Some(@units.Percentage(90.0)))
  assert_eq(full.sy, Some(@units.Percentage(80.0)))
  assert_eq(full.kx.unwrap().to_ooxml(), 60_000)
  assert_eq(full.ky.unwrap().to_ooxml(), 120_000)
  assert_true(full.alignment is Some(RectBottomLeft))
  assert_eq(full.rotate_with_shape, Some(false))
  // The base is untouched — builders are immutable (ADR-003).
  assert_true(base.sx is None)
}

///|
test "Reflection::default is empty; with_* set every attribute" {
  let r = @oxml.Reflection::default()
  assert_true(r.blur_rad is None && r.st_a is None && r.dir is None)
  let full = r
    .with_blur_rad(@units.Emu(6_350L))
    .with_alpha(start=@units.Percentage(60.0), end=@units.Percentage(0.0))
    .with_positions(start=@units.Percentage(0.0), end=@units.Percentage(55.0))
    .with_distance(@units.Emu(50_800L))
    .with_direction(@units.Angle::from_ooxml(5_400_000))
    .with_fade_direction(@units.Angle::from_ooxml(5_400_000))
    .with_scale(sx=@units.Percentage(100.0), sy=@units.Percentage(-100.0))
    .with_skew(
      kx=@units.Angle::from_ooxml(0),
      ky=@units.Angle::from_ooxml(30_000),
    )
    .with_alignment(RectBottomLeft)
    .with_rotate_with_shape(false)
  assert_eq(full.blur_rad, Some(@units.Emu(6_350L)))
  assert_eq(full.st_a, Some(@units.Percentage(60.0)))
  assert_eq(full.end_a, Some(@units.Percentage(0.0)))
  assert_eq(full.st_pos, Some(@units.Percentage(0.0)))
  assert_eq(full.end_pos, Some(@units.Percentage(55.0)))
  assert_eq(full.dist, Some(@units.Emu(50_800L)))
  assert_eq(full.dir.unwrap().to_ooxml(), 5_400_000)
  assert_eq(full.fade_dir.unwrap().to_ooxml(), 5_400_000)
  assert_eq(full.sx, Some(@units.Percentage(100.0)))
  assert_eq(full.sy, Some(@units.Percentage(-100.0)))
  assert_eq(full.kx.unwrap().to_ooxml(), 0)
  assert_eq(full.ky.unwrap().to_ooxml(), 30_000)
  assert_true(full.alignment is Some(RectBottomLeft))
  assert_eq(full.rotate_with_shape, Some(false))
}

///|
test "EffectList::empty + with_* build a list the writer round-trips" {
  let black = @oxml.Color::srgb(@units.RgbColor::new(0, 0, 0))
  let red = @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0x00, 0x00))
  let empty = @oxml.EffectList::empty()
  assert_true(empty.blur is None && empty.outer_shadow is None)
  assert_eq(empty.extension.length(), 0)
  let el = empty
    .with_blur(@oxml.Blur::new(@units.Emu(50_800L), grow=true))
    .with_glow(@oxml.Glow::new(@units.Emu(63_500L), red))
    .with_inner_shadow(
      @oxml.InnerShadow::new(
        blur_rad=@units.Emu(50_800L),
        dist=@units.Emu(25_400L),
        dir=@units.Angle::from_ooxml(2_700_000),
        color=black,
      ),
    )
    .with_outer_shadow(
      @oxml.OuterShadow::new(
        blur_rad=@units.Emu(50_800L),
        dist=@units.Emu(25_400L),
        dir=@units.Angle::from_ooxml(2_700_000),
        color=black,
      ).with_scale(sx=@units.Percentage(90.0), sy=@units.Percentage(90.0)),
    )
    .with_preset_shadow(
      @oxml.PresetShadow::new(
        "shdw4",
        dist=@units.Emu(38_100L),
        dir=@units.Angle::from_ooxml(5_400_000),
        color=black,
      ),
    )
    .with_reflection(
      @oxml.Reflection::default().with_blur_rad(@units.Emu(6_350L)),
    )
    .with_soft_edge(@oxml.SoftEdge::new(@units.Emu(12_700L)))
  // Every slot is set, and the whole list survives write -> parse.
  assert_true(el.blur is Some(_) && el.glow is Some(_))
  assert_true(el.inner_shadow is Some(_) && el.outer_shadow is Some(_))
  assert_true(el.preset_shadow is Some(_) && el.reflection is Some(_))
  assert_true(el.soft_edge is Some(_))
  assert_true(reparse_effect_list(el) == el)
}
