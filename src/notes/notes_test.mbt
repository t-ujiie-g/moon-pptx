// Speaker-notes parser tests.

///|
let pml_ns : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
let dml_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
/// UTF-8 encode a `String` to bytes. Mirrors the helper in `@slide` tests
/// — duplicated here because every `*_test.mbt` in a package compiles into
/// its own blackbox-test package, and `@slide`'s helper is private to that
/// test package.
fn fixture_bytes(s : String) -> FixedArray[Byte] {
  let buf : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp)
    } else if cp < 0x800 {
      buf.push(0xC0 | (cp >> 6))
      buf.push(0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      buf.push(0xE0 | (cp >> 12))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    } else {
      buf.push(0xF0 | (cp >> 18))
      buf.push(0x80 | ((cp >> 12) & 0x3F))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    }
  }
  let bytes = FixedArray::make(buf.length(), b'\x00')
  let mut i = 0
  while i < buf.length() {
    bytes[i] = buf[i].to_byte()
    i = i + 1
  }
  bytes
}

///|
/// A trimmed but realistic notes slide: the two canonical placeholders
/// (slide image + body) plus a body paragraph carrying the actual notes
/// text. Trailing `<p:custDataLst>` exercises the lossless-extension path.
fn typical_notes() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:notes xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld name=\"Slide 1 Notes\">" +
    "<p:spTree>" +
    "<p:nvGrpSpPr>" +
    "<p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/>" +
    "</p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    // Slide Image placeholder
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"2\" name=\"Slide Image Placeholder 1\"/>" +
    "<p:cNvSpPr><a:spLocks noGrp=\"1\" noRot=\"1\" noChangeAspect=\"1\"/></p:cNvSpPr>" +
    "<p:nvPr><p:ph type=\"sldImg\"/></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr/>" +
    "</p:sp>" +
    // Notes body placeholder
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"3\" name=\"Notes Placeholder 2\"/>" +
    "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>" +
    "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody>" +
    "<a:bodyPr/><a:lstStyle/>" +
    "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>Speaker notes here.</a:t></a:r></a:p>" +
    "</p:txBody>" +
    "</p:sp>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "<p:custDataLst><p:tags r:id=\"rId1\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"/></p:custDataLst>" +
    "</p:notes>"
  fixture_bytes(xml)
}

// --- happy path ---

///|
test "parse: notes name and shape count" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  assert_eq(notes.name, "Slide 1 Notes")
  assert_eq(notes.shapes.length(), 2) // sldImg + body placeholders
}

///|
test "parse: clrMapOvr defaults to MasterMapping" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  assert_true(
    notes.clr_map_override is @slide_master.ClrMapOverride::MasterMapping,
  )
}

///|
test "parse: slide-image placeholder metadata" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  match notes.shapes[0] {
    AutoShape(s) => {
      assert_eq(s.id, 2)
      assert_eq(s.name, "Slide Image Placeholder 1")
      let ph = s.placeholder.unwrap()
      assert_eq(ph.ph_type, "sldImg")
      assert_eq(ph.idx, 0) // missing idx defaults to 0
    }
    _ => panic()
  }
}

///|
test "parse: body placeholder carries the notes paragraph text" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  match notes.shapes[1] {
    AutoShape(s) => {
      let ph = s.placeholder.unwrap()
      assert_eq(ph.ph_type, "body")
      assert_eq(ph.idx, 1)
      let body = s.text_body.unwrap()
      assert_eq(body.plain_text(), "Speaker notes here.")
    }
    _ => panic()
  }
}

// --- lossless preservation ---

///|
test "parse: <p:custDataLst> rides on the slide-level extension" {
  let notes = @notes.NotesSlide::parse(typical_notes())
  // The slide-level extension captures the root-group metadata
  // (`<p:nvGrpSpPr>` + `<p:grpSpPr>`) followed by the `<p:custDataLst>`
  // sibling of `<p:cSld>` / `<p:clrMapOvr>` — three elements in source
  // order.  Cross-section ordering inside `extension` is not part of the
  // contract; the lookup uses local-name membership instead.
  assert_eq(notes.extension.length(), 3)
  let names = notes.extension.map(fn(e) { e.name.local_name })
  assert_true(names.contains("custDataLst"))
}

///|
test "parse: <p:extLst> alongside <p:clrMapOvr> is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:notes xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:extLst><p:ext uri=\"{ABCD}\"/></p:extLst>" +
    "</p:notes>"
  let notes = @notes.NotesSlide::parse(fixture_bytes(xml))
  assert_eq(notes.shapes.length(), 0)
  // 3 = nvGrpSpPr + grpSpPr (root-group metadata) + extLst sibling.
  assert_eq(notes.extension.length(), 3)
  let names = notes.extension.map(fn(e) { e.name.local_name })
  assert_true(names.contains("extLst"))
}

// --- error paths ---

///|
test "parse: wrong root element raises SlideFailure" {
  // The shared `Slide::parse_with_root` checks the root element before
  // any notes-specific logic runs, so the underlying SlideError surfaces
  // through SlideFailure rather than the local Malformed variant.
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let err = try? @notes.NotesSlide::parse(fixture_bytes(xml))
  assert_true(err is Err(@notes.NotesError::SlideFailure(_)))
}

///|
test "parse: empty bytes raises SlideFailure" {
  let err = try? @notes.NotesSlide::parse(FixedArray::make(0, b'\x00'))
  assert_true(err is Err(@notes.NotesError::SlideFailure(_)))
}
