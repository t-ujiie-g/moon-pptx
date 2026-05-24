// Tests for `Presentation::add_picture_mut`.

///|
/// Smallest possible 1×1 transparent PNG.  Hand-crafted so we don't
/// need to ship a real image fixture.
fn fake_png() -> FixedArray[Byte] {
  // PNG signature (8) + IHDR (25) + IDAT (12) + IEND (12)  = 67 bytes
  // The exact body doesn't matter — we only need the leading magic
  // bytes for the detector, and arbitrary trailing bytes for round-
  // trip preservation.
  let raw : Array[Int] = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
     0x00, 0x00, 0x00, 0x0D, // IHDR length
     0x49, 0x48, 0x44, 0x52, // "IHDR"
     0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
    0x1F, 0x15, 0xC4, 0x89, // CRC
     0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, // IDAT
     0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D,
    0xB4, // CRC
     0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
     0xAE, 0x42, 0x60, 0x82,
  ]
  let out = FixedArray::make(raw.length(), b'\x00')
  let mut i = 0
  while i < raw.length() {
    out[i] = raw[i].to_byte()
    i = i + 1
  }
  out
}

///|
fn jpeg_signature_bytes() -> FixedArray[Byte] {
  // Just the leading SOI + APP0 marker — enough for the detector
  // to recognise the format. Real PowerPoint won't render this as
  // an image but our test stops at "did we plumb the OPC parts".
  let raw : Array[Int] = [
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46,
  ]
  let out = FixedArray::make(raw.length(), b'\x00')
  let mut i = 0
  while i < raw.length() {
    out[i] = raw[i].to_byte()
    i = i + 1
  }
  out
}

///|
test "add_picture_mut: PNG path lands in /ppt/media as image/png" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(2_286_000L),
    @units.Emu(2_286_000L),
  )
  // The package now has a /ppt/media/image1.png part.
  let pkg = prs.pkg
  let img = pkg.part_by_name("/ppt/media/image1.png").unwrap()
  assert_eq(img.content_type, "image/png")
  // The slide's shape tree now contains a Picture referencing rId2
  // (rId1 is the layout link).
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    Picture(p) => {
      assert_eq(p.blip_fill.embed_id, "rId2")
      let xfrm = p.transform.unwrap()
      assert_eq(xfrm.offset.x, @units.Emu(914_400L))
      assert_eq(xfrm.extent.cx, @units.Emu(2_286_000L))
    }
    _ => fail("expected Picture shape")
  }
}

///|
test "add_picture_mut: JPEG path uses .jpeg extension + image/jpeg" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    jpeg_signature_bytes(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let img = prs.pkg.part_by_name("/ppt/media/image1.jpeg").unwrap()
  assert_eq(img.content_type, "image/jpeg")
}

///|
test "add_picture_mut: content_types gains a Default for the extension" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let cts = prs.pkg.content_types()
  let has_png_default = cts.defaults
    .iter()
    .any(fn(kv) { kv.0 == "png" && kv.1 == "image/png" })
  assert_true(has_png_default)
}

///|
test "add_picture_mut: second image gets image2 + a fresh rId" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
  assert_true(prs.pkg.part_by_name("/ppt/media/image2.png") is Some(_))
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 2)
}

///|
test "add_picture_mut: rejects unknown image format" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let garbage = FixedArray::make(16, b'\x00')
  let raised = try? prs.add_picture_mut(
    0,
    garbage,
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(raised is Err(@presentation.PptxError::Malformed(_)))
}

///|
test "add_picture_mut: rejects out-of-range slide index" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let raised = try? prs.add_picture_mut(
    99,
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(raised is Err(@presentation.PptxError::Malformed(_)))
}

///|
test "add_picture_mut: produced bytes reopen and round-trip" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(2_286_000L),
    @units.Emu(2_286_000L),
  )
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let slide = prs2.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    Picture(p) => assert_eq(p.blip_fill.embed_id, "rId2")
    _ => fail("expected Picture after reopen")
  }
  // Image bytes survived.
  let img = prs2.pkg.part_by_name("/ppt/media/image1.png").unwrap()
  assert_eq(img.bytes.length(), fake_png().length())
}
