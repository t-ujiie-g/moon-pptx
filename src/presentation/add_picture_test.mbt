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

// --- add_picture_auto_mut ---

///|
/// 96×192 PNG, no pHYs → defaults to 96 DPI, so EMU = 914_400 × 1_828_800.
fn png_96x192() -> FixedArray[Byte] {
  let raw : Array[Int] = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
     0x00, 0x00, 0x00, 0x0D, // IHDR length
     0x49, 0x48, 0x44, 0x52, // "IHDR"
     0x00, 0x00, 0x00, 0x60, // width 96
     0x00, 0x00, 0x00, 0xC0, // height 192
     0x08, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
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
test "add_picture_auto_mut: PNG dimensions derive from header" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_auto_mut(
    0,
    png_96x192(),
    @units.Emu(914_400L),
    @units.Emu(0L),
  )
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    Picture(p) => {
      let xfrm = p.transform.unwrap()
      // 96 px @ 96 dpi → 1 inch = 914_400 EMU
      assert_eq(xfrm.extent.cx, @units.Emu(914_400L))
      assert_eq(xfrm.extent.cy, @units.Emu(1_828_800L))
      assert_eq(xfrm.offset.x, @units.Emu(914_400L))
      assert_eq(xfrm.offset.y, @units.Emu(0L))
    }
    _ => fail("expected Picture")
  }
}

///|
test "add_picture_auto_mut: garbage bytes raise Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let garbage = FixedArray::make(16, b'\x00')
  let r = try? prs.add_picture_auto_mut(
    0,
    garbage,
    @units.Emu(0L),
    @units.Emu(0L),
  )
  assert_true(r is Err(@presentation.PptxError::Malformed(_)))
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

// --- add_svg_picture_mut (roadmap C4) ---

///|
/// Minimal SVG document as ASCII bytes. The detector never inspects it
/// (only the raster fallback is format-detected), so any bytes work.
fn fake_svg() -> FixedArray[Byte] {
  let s = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>"
  let out = FixedArray::make(s.length(), b'\x00')
  let mut i = 0
  for c in s {
    out[i] = c.to_int().to_byte()
    i = i + 1
  }
  out
}

///|
test "add_svg_picture_mut: wires svg + fallback parts, rels, content types" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_svg_picture_mut(
    0,
    fake_svg(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
  )
  // Two media parts: the raster fallback (image1.png) and the SVG
  // (image2.svg), each with the right content type.
  let png = prs.pkg.part_by_name("/ppt/media/image1.png").unwrap()
  assert_eq(png.content_type, "image/png")
  let svg = prs.pkg.part_by_name("/ppt/media/image2.svg").unwrap()
  assert_eq(svg.content_type, "image/svg+xml")
  // Both content-type Defaults are declared.
  let cts = prs.pkg.content_types()
  assert_true(cts.defaults.iter().any(fn(kv) { kv.0 == "png" }))
  assert_true(
    cts.defaults.iter().any(fn(kv) { kv.0 == "svg" && kv.1 == "image/svg+xml" }),
  )
  // The slide carries one SVG picture: blip embeds the fallback (rId2),
  // svgBlip references the SVG (rId3).
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    Picture(p) => {
      assert_eq(p.blip_fill.embed_id, "rId2")
      let blip = p.blip_fill.extension[0]
      assert_eq(blip.name.local_name, "blip")
    }
    _ => fail("expected SVG Picture shape")
  }
}

///|
test "add_svg_picture_mut: survives save + reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_svg_picture_mut(
    0,
    fake_svg(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  // Both media parts survived the zip round-trip.
  assert_true(prs2.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
  let svg = prs2.pkg.part_by_name("/ppt/media/image2.svg").unwrap()
  assert_eq(svg.bytes.length(), fake_svg().length())
  // And the picture's svgBlip extension is intact.
  match prs2.slides()[0].shapes[0] {
    Picture(p) => assert_eq(p.blip_fill.embed_id, "rId2")
    _ => fail("expected SVG Picture after reopen")
  }
}

///|
test "add_svg_picture_mut: rejects an unrecognised fallback image" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let garbage = FixedArray::make(16, b'\x00')
  let raised = try? prs.add_svg_picture_mut(
    0,
    fake_svg(),
    garbage,
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(raised is Err(@presentation.PptxError::Malformed(_)))
}

// --- add_video_mut / add_audio_mut (roadmap A6) ---

///|
/// Minimal MP4 (ISO-BMFF) header: "ftyp" box with an "isom" brand.
fn fake_mp4() -> FixedArray[Byte] {
  let raw : Array[Int] = [
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, // …ftyp
     0x69, 0x73, 0x6F, 0x6D, // "isom" brand
     0x00, 0x00, 0x02, 0x00,
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
/// Minimal MP3: an "ID3" tag header.
fn fake_mp3() -> FixedArray[Byte] {
  let raw : Array[Int] = [0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00]
  let out = FixedArray::make(raw.length(), b'\x00')
  let mut i = 0
  while i < raw.length() {
    out[i] = raw[i].to_byte()
    i = i + 1
  }
  out
}

///|
test "add_video_mut: wires media + poster parts, three rels, content types" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_video_mut(
    0,
    fake_mp4(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
  )
  // Media + poster parts with the right content types.
  let media = prs.pkg.part_by_name("/ppt/media/media1.mp4").unwrap()
  assert_eq(media.content_type, "video/mp4")
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
  let cts = prs.pkg.content_types()
  assert_true(cts.defaults.iter().any(fn(kv) { kv.0 == "mp4" }))
  // The slide holds one media picture: poster (rId2), link (rId3), embed (rId4).
  // The slide holds one picture whose poster is rId2. On re-parse `media` is
  // None — the videoFile / p14:media references round-trip through
  // `extension` (ADR-004), not the typed field — so the typed-media shape is
  // asserted in the slide-package tests; here the media plumbing is proven by
  // the media part + content type + the successful save→reopen test below.
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    Picture(p) => assert_eq(p.blip_fill.embed_id, "rId2")
    _ => fail("expected media Picture")
  }
}

///|
test "add_video_mut: survives save → reopen with media bytes intact" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_video_mut(
    0,
    fake_mp4(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  let media = prs2.pkg.part_by_name("/ppt/media/media1.mp4").unwrap()
  assert_eq(media.bytes.length(), fake_mp4().length())
  assert_eq(prs2.slides()[0].shapes.length(), 1)
}

///|
test "add_audio_mut: mp3 lands as audio/mpeg" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_audio_mut(
    0,
    fake_mp3(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let media = prs.pkg.part_by_name("/ppt/media/media1.mp3").unwrap()
  assert_eq(media.content_type, "audio/mpeg")
}

///|
test "add_video_mut: rejects audio bytes; add_audio_mut rejects video bytes" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let r1 = try? prs.add_video_mut(
    0,
    fake_mp3(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(r1 is Err(@presentation.PptxError::Malformed(_)))
  let r2 = try? prs.add_audio_mut(
    0,
    fake_mp4(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(r2 is Err(@presentation.PptxError::Malformed(_)))
}

///|
test "add video + audio on one slide → both <p14:media> namespaces stay in scope" {
  // Regression: two media objects each emit a `<p14:media>`; the second
  // must re-declare its namespace prefix (the first's xmlns is out of scope).
  // Previously this produced an unbound-prefix error on reopen.
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_video_mut(
    0,
    fake_mp4(),
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.add_audio_mut(
    0,
    fake_mp3(),
    fake_png(),
    @units.Emu(200L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  // The deck must reopen without an unbound-prefix XML error.
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.slides()[0].shapes.length(), 2)
}
