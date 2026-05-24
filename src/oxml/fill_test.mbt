// @oxml.Fill parser tests.

///|
fn parse_inner_fill(inner : String) -> @oxml.Fill raise @oxml.FillError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\" xmlns:r=\"" +
    @oxml.office_relationships_ns +
    "\">" +
    inner +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch {
    _ => raise @oxml.FillError::MalformedFill("test wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.FillError::MalformedFill("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(name, attrs)) => return @oxml.parse_fill(r, name, attrs)
      Some(EndElement(_)) =>
        raise @oxml.FillError::MalformedFill("empty wrapper")
      Some(_) => ()
      None =>
        raise @oxml.FillError::MalformedFill("unexpected end of test wrapper")
    }
  }
  raise @oxml.FillError::MalformedFill("unreachable")
}

// --- NoFill / SolidFill ---

///|
test "Fill: noFill" {
  let f = parse_inner_fill("<a:noFill/>")
  assert_true(f is @oxml.Fill::NoFill)
}

///|
test "Fill: solidFill with srgbClr" {
  let f = parse_inner_fill(
    "<a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>",
  )
  match f {
    SolidFill(c) =>
      match c.base {
        Srgb(rgb) => assert_eq(rgb.to_hex(), "FF0000")
        _ => fail("expected Srgb")
      }
    _ => fail("expected SolidFill")
  }
}

///|
test "Fill: solidFill missing colour child rejected" {
  let r = try? parse_inner_fill("<a:solidFill/>")
  assert_true(r is Err(@oxml.FillError::MalformedFill(_)))
}

// --- GradientFill ---

///|
test "Fill: linear gradient with two stops" {
  let inner = "<a:gradFill flip=\"none\" rotWithShape=\"1\">" +
    "<a:gsLst>" +
    "<a:gs pos=\"0\"><a:srgbClr val=\"FF0000\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"0000FF\"/></a:gs>" +
    "</a:gsLst>" +
    "<a:lin ang=\"5400000\" scaled=\"1\"/>" +
    "</a:gradFill>"
  let f = parse_inner_fill(inner)
  match f {
    GradientFill(g) => {
      assert_eq(g.stops.length(), 2)
      assert_eq(g.stops[0].position, @units.Percentage(0.0))
      assert_eq(g.stops[1].position, @units.Percentage(100.0))
      match g.direction {
        Linear(ang, scaled) => {
          assert_eq(ang, @units.Angle(90.0))
          assert_true(scaled)
        }
        _ => fail("expected Linear direction")
      }
      assert_eq(g.rotate_with_shape.unwrap(), true)
      assert_true(g.flip.unwrap() is @oxml.TileFlip::FlipNone)
    }
    _ => fail("expected GradientFill")
  }
}

///|
test "Fill: path gradient" {
  let inner = "<a:gradFill>" +
    "<a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"000000\"/></a:gs></a:gsLst>" +
    "<a:path path=\"circle\"/>" +
    "</a:gradFill>"
  let f = parse_inner_fill(inner)
  match f {
    GradientFill(g) =>
      assert_true(g.direction is @oxml.GradientDirection::PathCircle)
    _ => fail("expected GradientFill")
  }
}

///|
test "Fill: gradient with no stops rejected" {
  let r = try? parse_inner_fill(
    "<a:gradFill><a:gsLst/><a:lin ang=\"0\"/></a:gradFill>",
  )
  assert_true(r is Err(@oxml.FillError::MalformedFill(_)))
}

// --- PatternFill ---

///|
test "Fill: pattFill with fgClr and bgClr" {
  let inner = "<a:pattFill prst=\"dkUpDiag\">" +
    "<a:fgClr><a:srgbClr val=\"000000\"/></a:fgClr>" +
    "<a:bgClr><a:srgbClr val=\"FFFFFF\"/></a:bgClr>" +
    "</a:pattFill>"
  let f = parse_inner_fill(inner)
  match f {
    PatternFill(p) => {
      assert_eq(p.preset, "dkUpDiag")
      match p.fg.base {
        Srgb(rgb) => assert_eq(rgb.to_hex(), "000000")
        _ => fail("expected Srgb fg")
      }
      match p.bg.base {
        Srgb(rgb) => assert_eq(rgb.to_hex(), "FFFFFF")
        _ => fail("expected Srgb bg")
      }
    }
    _ => fail("expected PatternFill")
  }
}

///|
test "Fill: pattFill missing fgClr rejected" {
  let inner = "<a:pattFill prst=\"x\">" +
    "<a:bgClr><a:srgbClr val=\"FFFFFF\"/></a:bgClr>" +
    "</a:pattFill>"
  let r = try? parse_inner_fill(inner)
  assert_true(r is Err(@oxml.FillError::MalformedFill(_)))
}

// --- BlipFill ---

///|
test "Fill: blipFill with stretch + fillRect" {
  let inner = "<a:blipFill>" +
    "<a:blip r:embed=\"rId7\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(b) => {
      assert_eq(b.embed_id, "rId7")
      assert_eq(b.link_id, "")
      match b.fill_mode {
        Stretch(rect) => {
          let r = rect.unwrap()
          assert_eq(r.left, @units.Percentage(0.0))
        }
        _ => fail("expected Stretch")
      }
    }
    _ => fail("expected BlipFill")
  }
}

///|
test "Fill: blipFill with srcRect crop and tile mode" {
  let inner = "<a:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:srcRect l=\"10000\" t=\"20000\" r=\"5000\" b=\"5000\"/>" +
    "<a:tile tx=\"100\" ty=\"200\" sx=\"50000\" sy=\"50000\" flip=\"xy\" algn=\"ctr\"/>" +
    "</a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(b) => {
      let sr = b.src_rect.unwrap()
      assert_eq(sr.left, @units.Percentage(10.0))
      assert_eq(sr.top, @units.Percentage(20.0))
      match b.fill_mode {
        Tile(t) => {
          assert_eq(t.tx.unwrap(), @units.Emu(100L))
          assert_eq(t.ty.unwrap(), @units.Emu(200L))
          assert_eq(t.sx.unwrap(), @units.Percentage(50.0))
          assert_true(t.flip.unwrap() is @oxml.TileFlip::FlipXy)
          assert_true(t.alignment.unwrap() is @oxml.TileAlignment::AlignCenter)
        }
        _ => fail("expected Tile")
      }
    }
    _ => fail("expected BlipFill")
  }
}

///|
test "Fill: blipFill with linked rId only" {
  let inner = "<a:blipFill><a:blip r:link=\"rId9\"/></a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(b) => {
      assert_eq(b.embed_id, "")
      assert_eq(b.link_id, "rId9")
    }
    _ => fail("expected BlipFill")
  }
}

///|
test "Fill: blipFill with neither embed nor link rejected" {
  let inner = "<a:blipFill><a:blip/></a:blipFill>"
  let r = try? parse_inner_fill(inner)
  assert_true(r is Err(@oxml.FillError::MalformedFill(_)))
}

// --- error / unknown ---

///|
test "Fill: unknown wrapper rejected" {
  let r = try? parse_inner_fill("<a:weirdFill/>")
  assert_true(r is Err(@oxml.FillError::UnknownFillElement(_)))
}

///|
test "Fill: gs with bad color wrapped as ColorFailure" {
  let inner = "<a:gradFill>" +
    "<a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"GGGGGG\"/></a:gs></a:gsLst>" +
    "<a:lin ang=\"0\"/>" +
    "</a:gradFill>"
  let r = try? parse_inner_fill(inner)
  assert_true(r is Err(@oxml.FillError::ColorFailure(_)))
}
