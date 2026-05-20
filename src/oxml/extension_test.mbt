// Lossless preservation tests (ADR-004) for the @oxml ADTs —
// Phase 3f3d. Color, Fill (Gradient / Pattern / BlipFill), Stroke, and
// EffectList all gained an `extension : Array[@xml.XmlElement]` field;
// these tests assert that the unmodelled long-tail children round-trip.

// `parse_inner_fill` is defined in fill_test.mbt and shared via the
// blackbox test package; we reuse it here.

// --- Color.extension: unmodelled colour modifiers ---

///|
test "ADR-004: Color captures hueMod / redMod modifiers" {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<a:srgbClr val=\"112233\">" +
    "<a:tint val=\"50000\"/>" +
    "<a:hueMod val=\"180000\"/>" +
    "<a:redMod val=\"50000\"/>" +
    "</a:srgbClr>" +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch { _ => fail("wrapper open") }
  let ev = (r.next() catch { _ => fail("read inner") }).unwrap()
  let color = match ev {
    StartElement(n, a) =>
      @oxml.parse_color_element(r, n, a) catch {
        _ => fail("parse_color")
      }
    _ => fail("not a start element")
  }
  // tint was modelled → in transforms; hueMod + redMod fell through → in extension.
  assert_eq(color.transforms.length(), 1)
  assert_eq(color.extension.length(), 2)
  let names = []
  for el in color.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("hueMod"))
  assert_true(names.contains("redMod"))
}

// --- BlipFill.extension: <a:blip> colour-mod children survive ---

///|
test "ADR-004: BlipFill captures <a:blip> with nested duotone" {
  let inner = "<a:blipFill>" +
    "<a:blip r:embed=\"rId7\">" +
    "<a:duotone><a:srgbClr val=\"FF0000\"/><a:srgbClr val=\"00FF00\"/></a:duotone>" +
    "</a:blip>" +
    "<a:stretch/>" +
    "</a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(bf) => {
      assert_eq(bf.embed_id, "rId7")
      // The <a:blip> subtree is captured wholesale.
      assert_eq(bf.extension.length(), 1)
      let blip = bf.extension[0]
      assert_eq(blip.name.local_name, "blip")
      assert_eq(blip.children.length(), 1)
      match blip.children[0] {
        Element(duo) => {
          assert_eq(duo.name.local_name, "duotone")
          // duotone has two srgbClr children.
          assert_eq(duo.children.length(), 2)
        }
        _ => fail("expected duotone")
      }
    }
    _ => fail("expected BlipFillVariant")
  }
}

// --- Gradient.extension: tileRect survives ---

///|
test "ADR-004: Gradient captures <a:tileRect>" {
  let inner = "<a:gradFill>" +
    "<a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"FF0000\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"00FF00\"/></a:gs></a:gsLst>" +
    "<a:lin ang=\"5400000\" scaled=\"0\"/>" +
    "<a:tileRect l=\"0\" t=\"0\" r=\"50000\" b=\"50000\"/>" +
    "</a:gradFill>"
  let f = parse_inner_fill(inner)
  match f {
    GradientFill(g) => {
      assert_eq(g.stops.length(), 2)
      assert_eq(g.extension.length(), 1)
      assert_eq(g.extension[0].name.local_name, "tileRect")
    }
    _ => fail("expected GradientFill")
  }
}

// --- Stroke.extension: <a:custDash> and <a:extLst> survive ---

///|
test "ADR-004: Stroke captures custDash and extLst" {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<a:ln w=\"19050\">" +
    "<a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill>" +
    "<a:custDash><a:ds d=\"100000\" sp=\"50000\"/></a:custDash>" +
    "<a:extLst><a:ext uri=\"{x}\"/></a:extLst>" +
    "</a:ln>" +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch { _ => fail("wrapper open") }
  let ev = (r.next() catch { _ => fail("read ln") }).unwrap()
  let stroke = match ev {
    StartElement(_, attrs) =>
      @oxml.parse_stroke(r, attrs) catch {
        _ => fail("parse_stroke")
      }
    _ => fail("not a start element")
  }
  assert_eq(stroke.extension.length(), 2)
  let names = []
  for el in stroke.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("custDash"))
  assert_true(names.contains("extLst"))
}

// --- EffectList.extension: <a:fillOverlay> survives ---

///|
test "ADR-004: EffectList captures fillOverlay" {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<a:effectLst>" +
    "<a:blur rad=\"40000\"/>" +
    "<a:fillOverlay blend=\"over\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:fillOverlay>" +
    "</a:effectLst>" +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch { _ => fail("wrapper open") }
  let _ev = r.next() catch { _ => fail("read effectLst") }
  let el = @oxml.parse_effect_list(r) catch { _ => fail("parse_effect_list") }
  assert_true(el.blur is Some(_))
  assert_eq(el.extension.length(), 1)
  assert_eq(el.extension[0].name.local_name, "fillOverlay")
  assert_eq(el.extension[0].attributes[0].0.local_name, "blend")
  assert_eq(el.extension[0].attributes[0].1, "over")
}
