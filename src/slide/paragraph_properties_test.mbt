// ParagraphProperties parser tests.

///|
/// Build a slide with one paragraph whose `<a:pPr>` body is `ppr_body`,
/// followed by a single trivial run so the paragraph isn't empty.
fn slide_with_ppr(ppr_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody><a:p>" +
    ppr_body +
    "<a:r><a:t>x</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
fn ppr_of(s : @slide.Slide) -> @slide.ParagraphProperties {
  match s.shapes[0] {
    AutoShape(sp) => sp.text_body.unwrap().paragraphs[0].properties
    _ => abort("expected AutoShape")
  }
}

// --- attributes ---

///|
test "pPr: lvl level captured" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr lvl=\"2\"/>"))
  assert_eq(ppr_of(slide).level, 2)
}

///|
test "pPr: missing lvl defaults to 0" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr/>"))
  assert_eq(ppr_of(slide).level, 0)
}

///|
test "pPr: alignment values map to typed enum" {
  let cases = [
    ("l", @slide.TextAlignment::AlignLeft),
    ("ctr", @slide.TextAlignment::AlignCenter),
    ("r", @slide.TextAlignment::AlignRight),
    ("just", @slide.TextAlignment::AlignJustify),
    ("justLow", @slide.TextAlignment::AlignJustifyLow),
    ("dist", @slide.TextAlignment::AlignDistributed),
    ("thaiDist", @slide.TextAlignment::AlignThaiDistributed),
  ]
  for c in cases {
    let slide = @slide.Slide::parse(
      slide_with_ppr("<a:pPr algn=\"" + c.0 + "\"/>"),
    )
    assert_true(ppr_of(slide).alignment.unwrap() == c.1)
  }
}

///|
test "pPr: marL and indent (negative supported for hanging)" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr marL=\"457200\" indent=\"-457200\"/>"),
  )
  let p = ppr_of(slide)
  assert_eq(p.margin_left.unwrap(), @units.Emu(457200L))
  assert_eq(p.indent.unwrap(), @units.Emu(-457200L))
}

///|
test "pPr: lnSpc percent form (spcPct, 1/1000 %)" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:lnSpc><a:spcPct val=\"120000\"/></a:lnSpc></a:pPr>",
    ),
  )
  // 120000 OOXML units = 120 % line spacing.
  assert_true(
    ppr_of(slide).line_spacing == Some(Percent(@units.Percentage(120.0))),
  )
}

///|
test "pPr: lnSpc absolute form (spcPts, 1/100 pt) — F4" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr><a:lnSpc><a:spcPts val=\"1800\"/></a:lnSpc></a:pPr>"),
  )
  assert_true(ppr_of(slide).line_spacing == Some(Points(@units.Pt(18.0))))
}

///|
test "pPr: spcBef points + spcAft percent forms — F4" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr>" +
      "<a:spcBef><a:spcPts val=\"6000\"/></a:spcBef>" +
      "<a:spcAft><a:spcPct val=\"50000\"/></a:spcAft>" +
      "</a:pPr>",
    ),
  )
  let p = ppr_of(slide)
  assert_true(p.space_before == Some(Points(@units.Pt(60.0))))
  assert_true(p.space_after == Some(Percent(@units.Percentage(50.0))))
}

///|
test "pPr: spacing round-trips (parse → serialize → parse) — F4" {
  let xml = slide_with_ppr(
    "<a:pPr>" +
    "<a:lnSpc><a:spcPct val=\"150000\"/></a:lnSpc>" +
    "<a:spcBef><a:spcPts val=\"600\"/></a:spcBef>" +
    "<a:spcAft><a:spcPts val=\"1200\"/></a:spcAft>" +
    "</a:pPr>",
  )
  let s1 = @slide.Slide::parse(xml)
  let s2 = @slide.Slide::parse(s1.serialize())
  assert_true(ppr_of(s2) == ppr_of(s1))
  assert_true(ppr_of(s2).line_spacing is Some(Percent(_)))
}

///|
test "pPr: empty lnSpc (no choice child) raises — F4" {
  try @slide.Slide::parse(slide_with_ppr("<a:pPr><a:lnSpc/></a:pPr>")) catch {
    _ => ()
  } noraise {
    _ => fail("expected an empty <a:lnSpc> to raise")
  }
}

///|
test "pPr: spacing builders (with_line_spacing / before / after) — F4" {
  let para = @slide.Paragraph::of_text("hello")
    .with_line_spacing(Percent(@units.Percentage(120.0)))
    .with_space_before(Points(@units.Pt(6.0)))
    .with_space_after(Percent(@units.Percentage(40.0)))
  let body = @slide.TextBody::of_paragraphs([para])
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr/>")).map_shapes(s => {
    match s {
      AutoShape(sp) => AutoShape(sp.with_text_body(body))
      other => other
    }
  })
  let xml = @oxml.bytes_to_string(slide.serialize())
  assert_true(
    xml.find("<a:lnSpc><a:spcPct val=\"120000\"/></a:lnSpc>") is Some(_),
  )
  assert_true(
    xml.find("<a:spcBef><a:spcPts val=\"600\"/></a:spcBef>") is Some(_),
  )
  assert_true(
    xml.find("<a:spcAft><a:spcPct val=\"40000\"/></a:spcAft>") is Some(_),
  )
  // And the built spacing survives a reparse into the same model.
  let reparsed = @slide.Slide::parse(slide.serialize())
  assert_true(ppr_of(reparsed) == para.properties)
}

// --- bullets ---

///|
test "pPr: buNone explicit no-bullet" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr><a:buNone/></a:pPr>"))
  assert_true(ppr_of(slide).bullet.unwrap() is @slide.Bullet::BulNone)
}

///|
test "pPr: buChar carries the character" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr><a:buChar char=\"•\"/></a:pPr>"),
  )
  match ppr_of(slide).bullet.unwrap() {
    Char(s) => assert_eq(s, "•")
    _ => fail("expected Char bullet")
  }
}

///|
test "pPr: buAutoNum captures type and startAt" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:buAutoNum type=\"arabicPeriod\" startAt=\"3\"/></a:pPr>",
    ),
  )
  match ppr_of(slide).bullet.unwrap() {
    AutoNum(t, start) => {
      assert_true(t is @slide.AutoNumType::ArabicPeriod)
      assert_eq(start, 3)
    }
    _ => fail("expected AutoNum bullet")
  }
}

///|
test "pPr: buAutoNum default startAt is 1" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr><a:buAutoNum type=\"romanLcParenR\"/></a:pPr>"),
  )
  match ppr_of(slide).bullet.unwrap() {
    AutoNum(t, start) => {
      assert_true(t is @slide.AutoNumType::RomanLcParenR)
      assert_eq(start, 1)
    }
    _ => fail("expected AutoNum bullet")
  }
}

///|
test "pPr: buAutoNum with unknown type rejected" {
  try
    @slide.Slide::parse(
      slide_with_ppr(
        "<a:pPr><a:buAutoNum type=\"thisIsNotASchemeAtAll\"/></a:pPr>",
      ),
    )
  catch {
    @slide.SlideError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "pPr: buBlip captures r:id" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:buBlip><a:blip r:embed=\"rId7\"/></a:buBlip></a:pPr>",
    ),
  )
  match ppr_of(slide).bullet.unwrap() {
    Picture(rid) => assert_eq(rid, "rId7")
    _ => fail("expected Picture bullet")
  }
}

// --- absent / graceful ---

///|
test "pPr: missing attributes leave fields None" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr/>"))
  let p = ppr_of(slide)
  assert_true(p.alignment is None)
  assert_true(p.margin_left is None)
  assert_true(p.indent is None)
  assert_true(p.line_spacing is None)
  assert_true(p.space_before is None)
  assert_true(p.space_after is None)
  assert_true(p.bullet is None)
}

///|
test "pPr: unknown algn value collapses to None" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr algn=\"weird\"/>"))
  assert_true(ppr_of(slide).alignment is None)
}

///|
test "pPr: tabLst and other unmodelled children silently skipped" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:tabLst><a:tab pos=\"914400\" algn=\"l\"/></a:tabLst></a:pPr>",
    ),
  )
  // Did not raise; bullet stays None since tabLst doesn't define one.
  assert_true(ppr_of(slide).bullet is None)
}

///|
test "AutoNumType::from_xml round-trips a representative spread" {
  let cases = [
    "arabicPeriod", "arabicParenBoth", "romanUcPeriod", "romanLcParenR", "alphaUcPeriod",
    "alphaLcParenBoth", "circleNumDbPlain", "ea1JpnKorPeriod", "hindiAlphaPeriod",
    "thaiNumParenBoth",
  ]
  for c in cases {
    assert_true(!(@slide.AutoNumType::from_xml(c) is None))
  }
  assert_true(@slide.AutoNumType::from_xml("notAScheme") is None)
}
