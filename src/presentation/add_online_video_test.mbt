// Tests for online / URL video embedding (roadmap v0.5 C5).
//
// `fake_png` is shared from `add_picture_test.mbt` (same blackbox test package).

///|
/// Find the first relationship whose `rel_type` matches on `part_name`'s rels.
fn first_rel_of_type(
  prs : @presentation.Presentation,
  part_name : String,
  rel_type : String,
) -> @opc.Relationship? raise {
  let rels = prs.pkg.relationships_for(part_name)
  for r in rels.items {
    if r.rel_type == rel_type {
      return Some(r)
    }
  }
  None
}

///|
test "add_online_video_mut: poster part + external video/media rels, no media part" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  prs.add_online_video_mut(
    0,
    "https://example.com/clip.mp4",
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
  )
  // Poster image part exists; no /ppt/media part is created.
  assert_true(prs.pkg.part_by_name("/ppt/media/image1.png") is Some(_))
  assert_true(prs.pkg.part_by_name("/ppt/media/media1.mp4") is None)
  // The video + media rels are External and point at the URL.
  let video_rel = first_rel_of_type(prs, slide_name, @opc.rt_video).unwrap()
  assert_eq(video_rel.target, "https://example.com/clip.mp4")
  assert_true(video_rel.target_mode is External)
  let media_rel = first_rel_of_type(prs, slide_name, @opc.rt_media).unwrap()
  assert_eq(media_rel.target, "https://example.com/clip.mp4")
  assert_true(media_rel.target_mode is External)
  // The poster rel is Internal.
  let image_rel = first_rel_of_type(prs, slide_name, @opc.rt_image).unwrap()
  assert_true(image_rel.target_mode is Internal)
  // One media picture, poster blip = the image rId.
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    Picture(p) => assert_eq(p.blip_fill.embed_id, image_rel.id)
    _ => fail("expected media Picture")
  }
}

///|
test "add_online_video_mut: survives save -> reopen with external rel intact" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_online_video_mut(
    0,
    "https://example.com/clip.mp4",
    fake_png(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  let slide_name = "/ppt/slides/slide1.xml"
  let video_rel = first_rel_of_type(prs2, slide_name, @opc.rt_video).unwrap()
  assert_eq(video_rel.target, "https://example.com/clip.mp4")
  assert_true(video_rel.target_mode is External)
  assert_eq(prs2.slides()[0].shapes.length(), 1)
}

///|
test "add_youtube_video_mut: normalises watch / youtu.be / shorts / embed URLs" {
  let cases = [
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s",
    "https://youtu.be/dQw4w9WgXcQ", "https://youtu.be/dQw4w9WgXcQ?si=abc", "https://www.youtube.com/embed/dQw4w9WgXcQ",
    "https://www.youtube.com/shorts/dQw4w9WgXcQ",
  ]
  for url in cases {
    let prs = @presentation.Presentation::new()
    let slide_name = prs.add_slide_mut(0)
    prs.add_youtube_video_mut(
      0,
      url,
      fake_png(),
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
    let video_rel = first_rel_of_type(prs, slide_name, @opc.rt_video).unwrap()
    assert_eq(video_rel.target, "https://www.youtube.com/embed/dQw4w9WgXcQ")
    assert_true(video_rel.target_mode is External)
  }
}

///|
test "add_youtube_video_mut: rejects a URL with no video id" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try
    prs.add_youtube_video_mut(
      0,
      "https://example.com/not-a-video",
      fake_png(),
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "add_online_video_mut: rejects empty URL and bad poster" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // Empty URL.
  try
    prs.add_online_video_mut(
      0,
      "",
      fake_png(),
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed for empty URL")
  } noraise {
    _ => fail("expected Malformed for empty URL")
  }
  // Unrecognised poster bytes.
  try
    prs.add_online_video_mut(
      0,
      "https://example.com/clip.mp4",
      FixedArray::make(4, b'\x00'),
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed for bad poster")
  } noraise {
    _ => fail("expected Malformed for bad poster")
  }
}
