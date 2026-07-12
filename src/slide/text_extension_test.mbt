// Lossless preservation tests (ADR-004) for the text-side parsers.
// Targets the `extension` fields on TextBody, Paragraph, Run, Field,
// BodyProperties, ParagraphProperties, RunProperties, and ListStyle.

///|
test "ADR-004: TextBody captures foreign-namespace child" {
  let inner = "<a:bodyPr/><x:ext xmlns:x=\"http://example.org/ext\"/>" +
    "<a:p><a:r><a:t>Hi</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let tb = first_auto_shape(slide).text_body.unwrap()
  assert_eq(tb.extension.length(), 1)
  assert_eq(tb.extension[0].name.uri, "http://example.org/ext")
  assert_eq(tb.extension[0].name.local_name, "ext")
}

///|
test "ADR-004: BodyProperties captures prstTxWarp / extLst" {
  let inner = "<a:bodyPr>" +
    "<a:prstTxWarp prst=\"textArchUp\"><a:avLst/></a:prstTxWarp>" +
    "<a:extLst><a:ext uri=\"{x}\"/></a:extLst>" +
    "</a:bodyPr>" +
    "<a:p><a:r><a:t>x</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let bp = first_auto_shape(slide).text_body.unwrap().body_properties.unwrap()
  assert_eq(bp.extension.length(), 2)
  let names = []
  for el in bp.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("prstTxWarp"))
  assert_true(names.contains("extLst"))
}

///|
test "ADR-004: Paragraph captures endParaRPr" {
  let inner = "<a:p><a:r><a:t>hello</a:t></a:r><a:endParaRPr lang=\"en-US\" sz=\"1800\"/></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  assert_eq(p.extension.length(), 1)
  assert_eq(p.extension[0].name.local_name, "endParaRPr")
  // endParaRPr attributes survive too.
  assert_eq(p.extension[0].attributes.length(), 2)
}

///|
test "ADR-004: RunProperties captures hlinkMouseOver; effectLst now typed" {
  let inner = "<a:p><a:r>" +
    "<a:rPr lang=\"en-US\" b=\"1\">" +
    "<a:effectLst><a:outerShdw blurRad=\"40000\"><a:srgbClr val=\"000000\"/></a:outerShdw></a:effectLst>" +
    "<a:hlinkMouseOver r:id=\"rId7\" xmlns:r=\"" +
    off_rel_ns +
    "\"/>" +
    "</a:rPr>" +
    "<a:t>linked</a:t>" +
    "</a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[0] {
    RunContent(r) => {
      assert_eq(r.properties.bold.unwrap(), true)
      // effectLst lifts into the typed `text_effects` field; only the
      // still-unmodelled hlinkMouseOver remains in `extension`.
      assert_true(r.properties.text_effects is Some(_))
      assert_eq(r.properties.extension.length(), 1)
      assert_eq(r.properties.extension[0].name.local_name, "hlinkMouseOver")
    }
    _ => fail("expected Run")
  }
}

///|
test "ADR-004: ParagraphProperties captures buFont and tabLst" {
  let inner = "<a:p>" +
    "<a:pPr lvl=\"1\">" +
    "<a:buFont typeface=\"Symbol\" panose=\"05050102010706020507\"/>" +
    "<a:tabLst><a:tab pos=\"914400\" algn=\"l\"/></a:tabLst>" +
    "</a:pPr>" +
    "<a:r><a:t>x</a:t></a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  assert_eq(p.properties.level, 1)
  assert_eq(p.properties.extension.length(), 2)
  let names = []
  for el in p.properties.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("buFont"))
  assert_true(names.contains("tabLst"))
}

///|
test "ADR-004: ListStyle captures extLst" {
  let inner = "<a:lstStyle>" +
    "<a:defPPr><a:defRPr/></a:defPPr>" +
    "<a:extLst><a:ext uri=\"{x}\"><a:placeholder/></a:ext></a:extLst>" +
    "</a:lstStyle>" +
    "<a:p><a:r><a:t>x</a:t></a:r></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let ls = first_auto_shape(slide).text_body.unwrap().list_style.unwrap()
  assert_eq(ls.extension.length(), 1)
  assert_eq(ls.extension[0].name.local_name, "extLst")
}

///|
test "ADR-004: Field captures rPr extensions" {
  let inner = "<a:p><a:fld id=\"{F-0}\" type=\"slidenum\">" +
    "<a:rPr lang=\"en-US\"><a:extLst><a:ext uri=\"{x}\"/></a:extLst></a:rPr>" +
    "<a:t>1</a:t>" +
    "</a:fld></a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[0] {
    FieldContent(f) => {
      assert_eq(f.id, "{F-0}")
      assert_eq(f.text, "1")
      // The field's rPr extension carries the extLst.
      assert_eq(f.properties.extension.length(), 1)
      assert_eq(f.properties.extension[0].name.local_name, "extLst")
    }
    _ => fail("expected Field")
  }
}

///|
test "ADR-004: Break preserves its rPr (no longer drops it)" {
  let inner = "<a:p>" +
    "<a:r><a:t>one</a:t></a:r>" +
    "<a:br><a:rPr lang=\"en-US\" sz=\"2400\"/></a:br>" +
    "<a:r><a:t>two</a:t></a:r>" +
    "</a:p>"
  let slide = @slide.Slide::parse(slide_with_txbody(inner))
  let p = first_auto_shape(slide).text_body.unwrap().paragraphs[0]
  match p.content[1] {
    Break(rpr) => {
      assert_eq(rpr.lang, "en-US")
      assert_eq(rpr.font_size.unwrap(), @units.Pt(24.0))
    }
    _ => fail("expected Break")
  }
}
