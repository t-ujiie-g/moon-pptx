// @oxml.Color parser tests.

///|
/// Drive `parse_color_element` against the body of a `<wrapper>` element
/// whose payload is `inner`. The wrapper's outer namespace doesn't matter
/// — we just want the colour element + its modifier children.
fn parse_inner_color(inner : String) -> @oxml.Color raise @oxml.ColorError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    inner +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  // consume <wrapper>
  let _ = r.next() catch {
    _ => raise @oxml.ColorError::MalformedColor("test wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.ColorError::MalformedColor("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(name, attrs)) =>
        return @oxml.parse_color_element(r, name, attrs)
      Some(EndElement(_)) =>
        raise @oxml.ColorError::MalformedColor("empty wrapper")
      Some(_) => ()
      None =>
        raise @oxml.ColorError::MalformedColor("unexpected end of test wrapper")
    }
  }
  raise @oxml.ColorError::MalformedColor("unreachable")
}

// --- base colour kinds ---

///|
test "Color: srgbClr base" {
  let c = parse_inner_color("<a:srgbClr val=\"FF0000\"/>")
  match c.base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "FF0000")
    _ => fail("expected Srgb")
  }
  assert_eq(c.transforms.length(), 0)
}

///|
test "Color: schemeClr base" {
  let c = parse_inner_color("<a:schemeClr val=\"accent3\"/>")
  match c.base {
    Scheme(t) => assert_true(t is @units.ThemeColor::Accent3)
    _ => fail("expected Scheme")
  }
}

///|
test "Color: sysClr base with lastClr fallback" {
  let c = parse_inner_color("<a:sysClr val=\"windowText\" lastClr=\"000000\"/>")
  match c.base {
    Sys(s) => {
      assert_eq(s.val, "windowText")
      assert_eq(s.last_clr.unwrap().to_hex(), "000000")
    }
    _ => fail("expected Sys")
  }
}

///|
test "Color: hslClr base" {
  // hue: 1/60_000 deg, sat / lum: 1/1000 %
  let c = parse_inner_color(
    "<a:hslClr hue=\"7200000\" sat=\"50000\" lum=\"60000\"/>",
  )
  // 7_200_000 = 120 deg, 50_000 OOXML = 50%
  match c.base {
    Hsl(h) => {
      assert_eq(h.hue, 120.0)
      assert_eq(h.saturation, 50.0)
      assert_eq(h.lightness, 60.0)
    }
    _ => fail("expected Hsl")
  }
}

///|
test "Color: prstClr base preserves the preset name" {
  let c = parse_inner_color("<a:prstClr val=\"slateGray\"/>")
  match c.base {
    Preset(s) => assert_eq(s, "slateGray")
    _ => fail("expected Preset")
  }
}

///|
test "Color: scrgbClr base reads three percentages" {
  // 100% = 100_000 in OOXML 1/1000-percent units
  let c = parse_inner_color("<a:scrgbClr r=\"100000\" g=\"0\" b=\"50000\"/>")
  match c.base {
    Scrgb(r, g, b) => {
      assert_eq(r, @units.Percentage(100.0))
      assert_eq(g, @units.Percentage(0.0))
      assert_eq(b, @units.Percentage(50.0))
    }
    _ => fail("expected Scrgb")
  }
}

// --- transforms ---

///|
test "Color: tint + shade transforms preserved in source order" {
  let c = parse_inner_color(
    "<a:schemeClr val=\"accent1\"><a:tint val=\"40000\"/><a:shade val=\"20000\"/></a:schemeClr>",
  )
  assert_eq(c.transforms.length(), 2)
  match c.transforms[0] {
    Tint(p) => assert_eq(p, @units.Percentage(40.0))
    _ => fail("expected Tint")
  }
  match c.transforms[1] {
    Shade(p) => assert_eq(p, @units.Percentage(20.0))
    _ => fail("expected Shade")
  }
}

///|
test "Color: every supported transform variant" {
  let c = parse_inner_color(
    "<a:srgbClr val=\"112233\">" +
    "<a:tint val=\"50000\"/>" +
    "<a:shade val=\"50000\"/>" +
    "<a:satMod val=\"75000\"/>" +
    "<a:lumMod val=\"60000\"/>" +
    "<a:alpha val=\"80000\"/>" +
    "</a:srgbClr>",
  )
  assert_eq(c.transforms.length(), 5)
  assert_true(c.transforms[0] is Tint(_))
  assert_true(c.transforms[1] is Shade(_))
  assert_true(c.transforms[2] is SatMod(_))
  assert_true(c.transforms[3] is LumMod(_))
  assert_true(c.transforms[4] is Alpha(_))
}

///|
test "Color: long-tail modifiers (hueMod, redMod, comp) silently dropped" {
  // These appear in real PPTX but we don't model them today. We still need
  // to consume the subtree without raising or leaking events.
  let c = parse_inner_color(
    "<a:srgbClr val=\"FF0000\">" +
    "<a:hueMod val=\"50000\"/>" +
    "<a:redMod val=\"40000\"/>" +
    "<a:comp/>" +
    "</a:srgbClr>",
  )
  assert_eq(c.transforms.length(), 0)
}

// --- error paths ---

///|
test "Color: unknown colour element rejected" {
  let r = try? parse_inner_color("<a:weirdClr val=\"x\"/>")
  assert_true(r is Err(@oxml.ColorError::UnknownColorElement(_)))
}

///|
test "Color: srgbClr missing val rejected" {
  let r = try? parse_inner_color("<a:srgbClr/>")
  assert_true(r is Err(@oxml.ColorError::MalformedColor(_)))
}

///|
test "Color: srgbClr with bad hex rejected" {
  let r = try? parse_inner_color("<a:srgbClr val=\"GG0000\"/>")
  assert_true(r is Err(@oxml.ColorError::MalformedColor(_)))
}

///|
test "Color: schemeClr with unknown val rejected" {
  let r = try? parse_inner_color("<a:schemeClr val=\"weirdo\"/>")
  assert_true(r is Err(@oxml.ColorError::MalformedColor(_)))
}

// --- convenience constructors ---

///|
test "Color::srgb / Color::scheme constructors" {
  let c1 = @oxml.Color::srgb(@units.RgbColor::parse_hex("ABCDEF"))
  assert_true(c1.base is Srgb(_))
  assert_eq(c1.transforms.length(), 0)
  let c2 = @oxml.Color::scheme(@units.ThemeColor::Accent4)
  assert_true(c2.base is Scheme(_))
}
