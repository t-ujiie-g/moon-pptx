// Group shape parser tests (Phase 3c4) — recursive nesting.

///|
let grp_pml : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
let grp_a : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
fn grp_ascii(s : String) -> FixedArray[Byte] {
  let chars = s.to_array()
  let bytes = FixedArray::make(chars.length(), b'\x00')
  let mut i = 0
  while i < chars.length() {
    bytes[i] = chars[i].to_int().to_byte()
    i = i + 1
  }
  bytes
}

///|
fn slide_with_grp(inner : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    grp_pml +
    "\" xmlns:a=\"" +
    grp_a +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:grpSp>" +
    inner +
    "</p:grpSp>" +
    "</p:spTree></p:cSld></p:sld>"
  grp_ascii(xml)
}

// --- happy path ---

///|
test "parse: group shape with two child auto-shapes" {
  let inner = "<p:nvGrpSpPr>" +
    "<p:cNvPr id=\"10\" name=\"Group 1\"/>" +
    "<p:cNvGrpSpPr/>" +
    "<p:nvPr/>" +
    "</p:nvGrpSpPr>" +
    "<p:grpSpPr>" +
    "<a:xfrm>" +
    "<a:off x=\"0\" y=\"0\"/>" +
    "<a:ext cx=\"1000000\" cy=\"500000\"/>" +
    "<a:chOff x=\"0\" y=\"0\"/>" +
    "<a:chExt cx=\"1000000\" cy=\"500000\"/>" +
    "</a:xfrm>" +
    "</p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"11\" name=\"A\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "</p:sp>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"12\" name=\"B\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "</p:sp>"
  let slide = @slide.Slide::parse(slide_with_grp(inner))
  match slide.shapes[0] {
    Group(g) => {
      assert_eq(g.id, 10)
      assert_eq(g.name, "Group 1")
      let xfrm = g.transform.unwrap()
      assert_eq(xfrm.extent.cx, @units.Emu(1000000L))
      let cho = g.child_offset.unwrap()
      assert_eq(cho.x, @units.Emu(0L))
      let che = g.child_extent.unwrap()
      assert_eq(che.cx, @units.Emu(1000000L))
      assert_eq(g.children.length(), 2)
      // Children are AutoShapes in source order
      match g.children[0] {
        AutoShape(s) => assert_eq(s.id, 11)
        _ => fail("expected AutoShape at child 0")
      }
      match g.children[1] {
        AutoShape(s) => assert_eq(s.id, 12)
        _ => fail("expected AutoShape at child 1")
      }
    }
    _ => fail("expected Group")
  }
}

///|
test "parse: nested group shape (group inside group)" {
  let inner = "<p:nvGrpSpPr><p:cNvPr id=\"20\" name=\"Outer\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"21\" name=\"Inner\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"22\" name=\"Leaf\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "</p:sp>" +
    "</p:grpSp>"
  let slide = @slide.Slide::parse(slide_with_grp(inner))
  match slide.shapes[0] {
    Group(outer) => {
      assert_eq(outer.id, 20)
      assert_eq(outer.children.length(), 1)
      match outer.children[0] {
        Group(inner_g) => {
          assert_eq(inner_g.id, 21)
          assert_eq(inner_g.children.length(), 1)
          match inner_g.children[0] {
            AutoShape(s) => assert_eq(s.id, 22)
            _ => fail("expected leaf AutoShape")
          }
        }
        _ => fail("expected nested Group")
      }
    }
    _ => fail("expected outer Group")
  }
}

///|
test "parse: group shape with mixed child kinds (sp + pic + cxnSp)" {
  let inner = "<p:nvGrpSpPr><p:cNvPr id=\"30\" name=\"Mixed\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"31\" name=\"S\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr/>" +
    "</p:sp>" +
    "<p:pic>" +
    "<p:nvPicPr><p:cNvPr id=\"32\" name=\"P\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId1\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"/></p:blipFill>" +
    "<p:spPr/>" +
    "</p:pic>" +
    "<p:cxnSp>" +
    "<p:nvCxnSpPr><p:cNvPr id=\"33\" name=\"C\"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr/>" +
    "</p:cxnSp>"
  let slide = @slide.Slide::parse(slide_with_grp(inner))
  match slide.shapes[0] {
    Group(g) => {
      assert_eq(g.children.length(), 3)
      assert_true(g.children[0] is AutoShape(_))
      assert_true(g.children[1] is Picture(_))
      assert_true(g.children[2] is Connector(_))
    }
    _ => fail("expected Group")
  }
}

///|
test "parse: empty group shape (no child shapes)" {
  let inner = "<p:nvGrpSpPr><p:cNvPr id=\"40\" name=\"Empty\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>"
  let slide = @slide.Slide::parse(slide_with_grp(inner))
  match slide.shapes[0] {
    Group(g) => {
      assert_eq(g.id, 40)
      assert_eq(g.children.length(), 0)
      assert_true(g.transform is None)
      assert_true(g.child_offset is None)
      assert_true(g.child_extent is None)
    }
    _ => fail("expected Group")
  }
}

///|
test "parse: group with chOff/chExt but no off/ext" {
  // Only the child coordinate space defined (no own placement).
  let inner = "<p:nvGrpSpPr><p:cNvPr id=\"50\" name=\"x\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm>" +
    "<a:chOff x=\"100\" y=\"200\"/>" +
    "<a:chExt cx=\"300\" cy=\"400\"/>" +
    "</a:xfrm></p:grpSpPr>"
  let slide = @slide.Slide::parse(slide_with_grp(inner))
  match slide.shapes[0] {
    Group(g) => {
      assert_true(g.transform is None) // off + ext both missing
      let cho = g.child_offset.unwrap()
      assert_eq(cho.x, @units.Emu(100L))
      let che = g.child_extent.unwrap()
      assert_eq(che.cx, @units.Emu(300L))
    }
    _ => fail("expected Group")
  }
}
