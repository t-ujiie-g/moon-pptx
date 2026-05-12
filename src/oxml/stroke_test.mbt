// @oxml.Stroke parser tests (Phase 3e3).

///|
fn parse_stroke_inner(inner : String) -> @oxml.Stroke raise @oxml.StrokeError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    inner +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch {
    _ => raise @oxml.StrokeError::MalformedStroke("test wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.StrokeError::MalformedStroke("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(_, attrs)) => return @oxml.parse_stroke(r, attrs)
      Some(EndElement(_)) =>
        raise @oxml.StrokeError::MalformedStroke("empty wrapper")
      Some(_) => ()
      None =>
        raise @oxml.StrokeError::MalformedStroke(
          "unexpected end of test wrapper",
        )
    }
  }
  raise @oxml.StrokeError::MalformedStroke("unreachable")
}

// --- attributes ---

///|
test "Stroke: attributes (width / cap / cmpd / algn)" {
  let s = parse_stroke_inner(
    "<a:ln w=\"9525\" cap=\"rnd\" cmpd=\"dbl\" algn=\"ctr\"/>",
  )
  assert_eq(s.width.unwrap(), @units.Emu(9525L))
  assert_true(s.cap.unwrap() is @oxml.LineCap::CapRound)
  assert_true(s.compound.unwrap() is @oxml.CompoundLine::CmpdDouble)
  assert_true(s.alignment.unwrap() is @oxml.PenAlignment::AlignPenCenter)
}

///|
test "Stroke: missing attributes leave fields None" {
  let s = parse_stroke_inner("<a:ln/>")
  assert_true(s.width is None)
  assert_true(s.cap is None)
  assert_true(s.compound is None)
  assert_true(s.alignment is None)
  assert_true(s.fill is None)
  assert_true(s.dash is None)
  assert_true(s.join is None)
  assert_true(s.head_end is None)
  assert_true(s.tail_end is None)
}

// --- fill child ---

///|
test "Stroke: solidFill colour child" {
  let s = parse_stroke_inner(
    "<a:ln w=\"6350\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:ln>",
  )
  match s.fill.unwrap() {
    SolidFill(c) =>
      match c.base {
        Srgb(rgb) => assert_eq(rgb.to_hex(), "FF0000")
        _ => fail("expected Srgb base")
      }
    _ => fail("expected SolidFill")
  }
}

///|
test "Stroke: noFill child" {
  let s = parse_stroke_inner("<a:ln><a:noFill/></a:ln>")
  assert_true(s.fill.unwrap() is @oxml.Fill::NoFill)
}

// --- dash / join / arrows ---

///|
test "Stroke: prstDash carries enum" {
  let s = parse_stroke_inner("<a:ln><a:prstDash val=\"dashDot\"/></a:ln>")
  assert_true(s.dash.unwrap() is @oxml.DashStyle::DashDashDot)
}

///|
test "Stroke: round / bevel / miter line joins" {
  let r = parse_stroke_inner("<a:ln><a:round/></a:ln>")
  assert_true(r.join.unwrap() is @oxml.LineJoin::JoinRound)
  let b = parse_stroke_inner("<a:ln><a:bevel/></a:ln>")
  assert_true(b.join.unwrap() is @oxml.LineJoin::JoinBevel)
  let m = parse_stroke_inner("<a:ln><a:miter lim=\"800000\"/></a:ln>")
  match m.join.unwrap() {
    JoinMiter(Some(p)) => assert_eq(p, @units.Percentage(800.0))
    _ => fail("expected JoinMiter with limit")
  }
}

///|
test "Stroke: miter without limit attribute" {
  let s = parse_stroke_inner("<a:ln><a:miter/></a:ln>")
  match s.join.unwrap() {
    JoinMiter(None) => ()
    _ => fail("expected JoinMiter(None)")
  }
}

///|
test "Stroke: head + tail arrowheads" {
  let s = parse_stroke_inner(
    "<a:ln><a:headEnd type=\"triangle\" w=\"med\" len=\"lg\"/>" +
    "<a:tailEnd type=\"arrow\" w=\"sm\"/></a:ln>",
  )
  let h = s.head_end.unwrap()
  assert_true(h.arrow_type is @oxml.ArrowType::ArrowTriangle)
  assert_true(h.width.unwrap() is @oxml.ArrowSize::SizeMedium)
  assert_true(h.length.unwrap() is @oxml.ArrowSize::SizeLarge)
  let t = s.tail_end.unwrap()
  assert_true(t.arrow_type is @oxml.ArrowType::ArrowArrow)
  assert_true(t.width.unwrap() is @oxml.ArrowSize::SizeSmall)
  assert_true(t.length is None)
}

///|
test "Stroke: arrowhead with missing type defaults to None" {
  let s = parse_stroke_inner("<a:ln><a:headEnd w=\"med\"/></a:ln>")
  let h = s.head_end.unwrap()
  assert_true(h.arrow_type is @oxml.ArrowType::ArrowNone)
}

// --- combined ---

///|
test "Stroke: realistic outline (width + solid colour + dash + arrows)" {
  let inner = "<a:ln w=\"9525\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\">" +
    "<a:solidFill><a:srgbClr val=\"0000FF\"/></a:solidFill>" +
    "<a:prstDash val=\"sysDash\"/>" +
    "<a:round/>" +
    "<a:tailEnd type=\"stealth\" w=\"med\" len=\"med\"/>" +
    "</a:ln>"
  let s = parse_stroke_inner(inner)
  assert_eq(s.width.unwrap(), @units.Emu(9525L))
  assert_true(s.cap.unwrap() is @oxml.LineCap::CapFlat)
  assert_true(s.dash.unwrap() is @oxml.DashStyle::DashSysDash)
  assert_true(s.join.unwrap() is @oxml.LineJoin::JoinRound)
  assert_true(s.head_end is None)
  assert_true(s.tail_end.unwrap().arrow_type is @oxml.ArrowType::ArrowStealth)
}

///|
test "Stroke: unknown enum values collapse to None (graceful)" {
  let s = parse_stroke_inner(
    "<a:ln cap=\"weirdo\"><a:prstDash val=\"alsoUnknown\"/></a:ln>",
  )
  assert_true(s.cap is None)
  assert_true(s.dash is None)
}

///|
test "Stroke: custDash is silently skipped" {
  let inner = "<a:ln><a:custDash><a:ds d=\"100\" sp=\"50\"/></a:custDash></a:ln>"
  let s = parse_stroke_inner(inner)
  assert_true(s.dash is None)
}

// --- error / fill-failure ---

///|
test "Stroke: bad colour inside solidFill wraps as FillFailure" {
  let r = try? parse_stroke_inner(
    "<a:ln><a:solidFill><a:srgbClr val=\"GGGGGG\"/></a:solidFill></a:ln>",
  )
  assert_true(r is Err(@oxml.StrokeError::FillFailure(_)))
}
