// Tests for the typed slide background (`<p:bg>`).

///|
/// Wrap a `<p:cSld>` body (the `<p:bg>` plus a minimal empty spTree) into a
/// parseable `<p:sld>`.
fn slide_with_bg(bg : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld>" +
    bg +
    "<p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/></p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- parse ---

///|
test "background: parse <p:bgRef> into StyleReference" {
  let slide = @slide.Slide::parse(
    slide_with_bg(
      "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>",
    ),
  )
  match slide.background {
    Some(StyleReference(idx, color)) => {
      assert_eq(idx, 1001)
      assert_true(color.base is Scheme(_))
    }
    _ => fail("expected StyleReference background")
  }
}

///|
test "background: parse <p:bgPr> solid fill" {
  let slide = @slide.Slide::parse(
    slide_with_bg(
      "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>" +
      "<a:effectLst/></p:bgPr></p:bg>",
    ),
  )
  match slide.background {
    Some(Properties(p)) => {
      assert_false(p.shade_to_title)
      assert_true(p.fill is Some(SolidFill(_)))
    }
    _ => fail("expected Properties background")
  }
}

///|
test "background: shadeToTitle attribute is read" {
  let slide = @slide.Slide::parse(
    slide_with_bg(
      "<p:bg><p:bgPr shadeToTitle=\"1\"><a:noFill/></p:bgPr></p:bg>",
    ),
  )
  match slide.background {
    Some(Properties(p)) => {
      assert_true(p.shade_to_title)
      assert_true(p.fill is Some(NoFill))
    }
    _ => fail("expected Properties background")
  }
}

///|
test "background: unmodelled grpFill is preserved (ADR-004), fill stays None" {
  let slide = @slide.Slide::parse(
    slide_with_bg("<p:bg><p:bgPr><a:grpFill/></p:bgPr></p:bg>"),
  )
  match slide.background {
    Some(Properties(p)) => {
      assert_true(p.fill is None)
      assert_eq(p.extension.length(), 1)
      assert_eq(p.extension[0].name.local_name, "grpFill")
    }
    _ => fail("expected Properties background")
  }
}

///|
test "background: absent <p:bg> reads as None" {
  let slide = @slide.Slide::parse(slide_with_bg(""))
  assert_true(slide.background is None)
}

// --- round-trip (parse → serialize → parse via Eq) ---

///|
test "background: bgPr solid-fill round-trips" {
  let bytes = slide_with_bg(
    "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"112233\"/></a:solidFill>" +
    "</p:bgPr></p:bg>",
  )
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  assert_true(s1.background == s0.background)
}

///|
test "background: bgRef round-trips" {
  let bytes = slide_with_bg(
    "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg2\"/></p:bgRef></p:bg>",
  )
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  assert_true(s1.background == s0.background)
}

///|
test "background: grpFill round-trips losslessly" {
  let bytes = slide_with_bg("<p:bg><p:bgPr><a:grpFill/></p:bgPr></p:bg>")
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  assert_true(s1.background == s0.background)
}

///|
test "background: <p:bg> serialises before <p:spTree>" {
  let bytes = slide_with_bg(
    "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>" +
    "</p:bgPr></p:bg>",
  )
  let slide = @slide.Slide::parse(bytes)
  let xml = @oxml.bytes_to_string(slide.serialize())
  let bg_at = xml.find("<p:bg>").unwrap()
  let sptree_at = xml.find("<p:spTree>").unwrap()
  assert_true(bg_at >= 0)
  assert_true(bg_at < sptree_at)
}

// --- builders ---

///|
test "background: Slide::with_background sets a solid-fill bgPr" {
  let slide = @slide.Slide::parse(slide_with_bg("")).with_background(
    SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0x11, 0x66, 0xCC))),
  )
  match slide.background {
    Some(Properties(p)) => assert_true(p.fill is Some(SolidFill(_)))
    _ => fail("expected Properties background")
  }
  // …and it survives serialisation.
  let s1 = @slide.Slide::parse(slide.serialize())
  assert_true(s1.background == slide.background)
}

///|
test "background: with_background_ref / without_background" {
  let base = @slide.Slide::parse(slide_with_bg(""))
  let ref_slide = base.with_background_ref(
    1002,
    @oxml.Color::scheme(@units.ThemeColor::Bg1),
  )
  match ref_slide.background {
    Some(StyleReference(idx, _)) => assert_eq(idx, 1002)
    _ => fail("expected StyleReference background")
  }
  // Clearing yields no background.
  assert_true(ref_slide.without_background().background is None)
}

///|
test "BackgroundProperties::of_fill wraps the fill with defaults" {
  let fill = @oxml.Fill::SolidFill(
    @oxml.Color::srgb(@units.RgbColor::new(0x10, 0x20, 0x30)),
  )
  let p = @slide.BackgroundProperties::of_fill(fill)
  assert_true(p.fill == Some(fill))
  assert_eq(p.shade_to_title, false)
  assert_true(p.effects is None)
  assert_eq(p.extension.length(), 0)
}
