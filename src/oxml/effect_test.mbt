// @oxml.EffectList parser tests (Phase 3e4).

///|
let drawing_effect : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
fn parse_effect_list_inner(
  inner : String,
) -> @oxml.EffectList raise @oxml.EffectError {
  let xml = "<wrapper xmlns:a=\"" +
    drawing_effect +
    "\"><a:effectLst>" +
    inner +
    "</a:effectLst></wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch {
    _ => raise @oxml.EffectError::MalformedEffect("test wrapper open failed")
  }
  // advance to <a:effectLst> StartElement
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.EffectError::MalformedEffect("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(_, _)) => return @oxml.parse_effect_list(r)
      Some(EndElement(_)) =>
        raise @oxml.EffectError::MalformedEffect("empty wrapper")
      Some(_) => ()
      None =>
        raise @oxml.EffectError::MalformedEffect(
          "unexpected end of test wrapper",
        )
    }
  }
  raise @oxml.EffectError::MalformedEffect("unreachable")
}

// --- empty effectLst ---

///|
test "EffectList: empty list parses to all-None" {
  let fx = parse_effect_list_inner("")
  assert_true(fx.blur is None)
  assert_true(fx.glow is None)
  assert_true(fx.inner_shadow is None)
  assert_true(fx.outer_shadow is None)
  assert_true(fx.preset_shadow is None)
  assert_true(fx.reflection is None)
  assert_true(fx.soft_edge is None)
}

// --- blur ---

///|
test "EffectList: blur with rad + grow" {
  let fx = parse_effect_list_inner("<a:blur rad=\"50800\" grow=\"1\"/>")
  let b = fx.blur.unwrap()
  assert_eq(b.rad, @units.Emu(50800L))
  assert_eq(b.grow.unwrap(), true)
}

///|
test "EffectList: blur missing rad raises" {
  let res = try? parse_effect_list_inner("<a:blur/>")
  assert_true(res is Err(_))
}

// --- glow ---

///|
test "EffectList: glow with srgb colour" {
  let fx = parse_effect_list_inner(
    "<a:glow rad=\"63500\"><a:srgbClr val=\"FFC000\"/></a:glow>",
  )
  let g = fx.glow.unwrap()
  assert_eq(g.rad, @units.Emu(63500L))
  match g.color.base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "FFC000")
    _ => fail("expected Srgb base")
  }
}

///|
test "EffectList: glow without colour raises" {
  let res = try? parse_effect_list_inner("<a:glow rad=\"63500\"/>")
  assert_true(res is Err(_))
}

// --- innerShdw ---

///|
test "EffectList: innerShdw full" {
  let fx = parse_effect_list_inner(
    "<a:innerShdw blurRad=\"50800\" dist=\"38100\" dir=\"2700000\"><a:srgbClr val=\"000000\"/></a:innerShdw>",
  )
  let s = fx.inner_shadow.unwrap()
  assert_eq(s.blur_rad, @units.Emu(50800L))
  assert_eq(s.dist, @units.Emu(38100L))
  assert_eq(s.dir, @units.Angle::from_ooxml(2700000))
  match s.color.base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "000000")
    _ => fail("expected Srgb base")
  }
}

// --- outerShdw ---

///|
test "EffectList: outerShdw with optionals" {
  let fx = parse_effect_list_inner(
    "<a:outerShdw blurRad=\"50800\" dist=\"38100\" dir=\"5400000\" sx=\"100000\" sy=\"100000\" algn=\"b\" rotWithShape=\"0\"><a:srgbClr val=\"333333\"/></a:outerShdw>",
  )
  let s = fx.outer_shadow.unwrap()
  assert_eq(s.blur_rad, @units.Emu(50800L))
  assert_eq(s.dist, @units.Emu(38100L))
  assert_eq(s.dir, @units.Angle::from_ooxml(5400000))
  assert_eq(s.sx.unwrap(), @units.Percentage::from_ooxml(100000))
  assert_eq(s.sy.unwrap(), @units.Percentage::from_ooxml(100000))
  assert_true(s.alignment.unwrap() is @oxml.RectAlignment::RectBottom)
  assert_eq(s.rotate_with_shape.unwrap(), false)
}

///|
test "EffectList: outerShdw minimal (no optionals)" {
  let fx = parse_effect_list_inner(
    "<a:outerShdw blurRad=\"40000\" dist=\"20000\" dir=\"2700000\"><a:srgbClr val=\"808080\"/></a:outerShdw>",
  )
  let s = fx.outer_shadow.unwrap()
  assert_true(s.sx is None)
  assert_true(s.sy is None)
  assert_true(s.kx is None)
  assert_true(s.ky is None)
  assert_true(s.alignment is None)
  assert_true(s.rotate_with_shape is None)
}

// --- prstShdw ---

///|
test "EffectList: prstShdw" {
  let fx = parse_effect_list_inner(
    "<a:prstShdw prst=\"shdw17\" dist=\"38100\" dir=\"2700000\"><a:srgbClr val=\"AABBCC\"/></a:prstShdw>",
  )
  let s = fx.preset_shadow.unwrap()
  assert_eq(s.preset, "shdw17")
  assert_eq(s.dist, @units.Emu(38100L))
  match s.color.base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "AABBCC")
    _ => fail("expected Srgb base")
  }
}

// --- softEdge ---

///|
test "EffectList: softEdge with rad" {
  let fx = parse_effect_list_inner("<a:softEdge rad=\"31750\"/>")
  let s = fx.soft_edge.unwrap()
  assert_eq(s.rad, @units.Emu(31750L))
}

// --- reflection ---

///|
test "EffectList: reflection with several attrs" {
  let fx = parse_effect_list_inner(
    "<a:reflection blurRad=\"6350\" stA=\"60000\" stPos=\"0\" endA=\"300\" endPos=\"60000\" dist=\"50800\" dir=\"5400000\" sy=\"-100000\" algn=\"bl\" rotWithShape=\"0\"/>",
  )
  let r = fx.reflection.unwrap()
  assert_eq(r.blur_rad.unwrap(), @units.Emu(6350L))
  assert_eq(r.dist.unwrap(), @units.Emu(50800L))
  assert_eq(r.sy.unwrap(), @units.Percentage::from_ooxml(-100000))
  assert_true(r.alignment.unwrap() is @oxml.RectAlignment::RectBottomLeft)
  assert_eq(r.rotate_with_shape.unwrap(), false)
}

///|
test "EffectList: reflection bare (all attrs optional)" {
  let fx = parse_effect_list_inner("<a:reflection/>")
  let r = fx.reflection.unwrap()
  assert_true(r.blur_rad is None)
  assert_true(r.dist is None)
  assert_true(r.dir is None)
  assert_true(r.alignment is None)
}

// --- combined ---

///|
test "EffectList: glow + outerShdw together" {
  let fx = parse_effect_list_inner(
    "<a:glow rad=\"63500\"><a:srgbClr val=\"FFC000\"/></a:glow>" +
    "<a:outerShdw blurRad=\"40000\" dist=\"20000\" dir=\"2700000\"><a:srgbClr val=\"000000\"/></a:outerShdw>",
  )
  assert_true(!(fx.glow is None))
  assert_true(!(fx.outer_shadow is None))
  assert_true(fx.blur is None)
}

// --- unknown / skipped children ---

///|
test "EffectList: unknown child is skipped, others still parse" {
  let fx = parse_effect_list_inner(
    "<a:fillOverlay blend=\"over\"><a:srgbClr val=\"FF0000\"/></a:fillOverlay>" +
    "<a:softEdge rad=\"12700\"/>",
  )
  let s = fx.soft_edge.unwrap()
  assert_eq(s.rad, @units.Emu(12700L))
}

// --- RectAlignment::from_xml ---

///|
test "RectAlignment::from_xml round-trips known values" {
  assert_true(
    @oxml.RectAlignment::from_xml("tl").unwrap()
    is @oxml.RectAlignment::RectTopLeft,
  )
  assert_true(
    @oxml.RectAlignment::from_xml("ctr").unwrap()
    is @oxml.RectAlignment::RectCenter,
  )
  assert_true(
    @oxml.RectAlignment::from_xml("br").unwrap()
    is @oxml.RectAlignment::RectBottomRight,
  )
  assert_true(@oxml.RectAlignment::from_xml("bogus") is None)
}
