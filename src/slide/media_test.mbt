// Tests for media pictures.
// Reuses `slide_of_picture` (svg_picture_test.mbt) and `char_index_of`
// (background_test.mbt) from this blackbox test package.

///|
test "Picture::of_media: builds a video reference + poster blip" {
  let pic = @slide.Picture::of_media(
    5,
    "clip.mp4",
    Video,
    "rId3", // <a:videoFile r:link>
    "rId4", // <p14:media r:embed>
    "rId2", // poster <a:blip r:embed>
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
  )
  // Poster is the blipFill embed.
  assert_eq(pic.blip_fill.embed_id, "rId2")
  match pic.media {
    Some(m) => {
      assert_true(m.kind is Video)
      assert_eq(m.link_id, "rId3")
      assert_eq(m.embed_id, "rId4")
    }
    None => fail("expected media info")
  }
}

///|
test "media picture serialises videoFile + p14:media + media action" {
  let pic = @slide.Picture::of_media(
    7,
    "clip.mp4",
    Video,
    "rId3",
    "rId4",
    "rId2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let xml = @oxml.bytes_to_string(slide_of_picture(pic).serialize())
  assert_true(char_index_of(xml, "<a:videoFile") >= 0)
  assert_true(char_index_of(xml, "media") >= 0) // p14:media
  assert_true(char_index_of(xml, "ppaction://media") >= 0)
  assert_true(char_index_of(xml, @oxml.media_ext_uri) >= 0)
  assert_true(char_index_of(xml, @oxml.powerpoint_2010_ns) >= 0)
}

///|
test "audio media emits audioFile" {
  let pic = @slide.Picture::of_media(
    8,
    "clip.mp3",
    Audio,
    "rId3",
    "rId4",
    "rId2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let xml = @oxml.bytes_to_string(slide_of_picture(pic).serialize())
  assert_true(char_index_of(xml, "<a:audioFile") >= 0)
}

///|
test "media XML round-trips losslessly (re-serialise is stable)" {
  let pic = @slide.Picture::of_media(
    9,
    "clip.mp4",
    Video,
    "rId3",
    "rId4",
    "rId2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  // First serialise (typed media path), then parse — the parser captures the
  // media nv-children into `extension` (media stays None) — then serialise
  // again. The media elements must survive that second pass verbatim.
  let bytes1 = slide_of_picture(pic).serialize()
  let reparsed = @slide.Slide::parse(bytes1)
  let xml2 = @oxml.bytes_to_string(reparsed.serialize())
  assert_true(char_index_of(xml2, "<a:videoFile") >= 0)
  assert_true(char_index_of(xml2, "ppaction://media") >= 0)
  assert_true(char_index_of(xml2, @oxml.media_ext_uri) >= 0)
}

///|
/// Issue #11 regression: after a parse→serialise round-trip (where the media
/// reference is captured into `extension`, not the typed `media` field), the
/// `<a:videoFile>` and the media `<p:extLst>` must still sit *inside* `<p:nvPr>`
/// — not as direct children of `<p:pic>`, which is invalid `CT_Picture` content
/// and made PowerPoint repair the deck. The pre-fix code mis-classified the
/// drawing-ml `<a:videoFile>` to the shape body. Presence-only checks (above)
/// missed it; this asserts *placement*.
test "issue #11: media nv-children stay inside <p:nvPr> after round-trip" {
  let pic = @slide.Picture::of_media(
    9,
    "clip.mp4",
    Video,
    "rId3",
    "rId4",
    "rId2",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let xml = @oxml.bytes_to_string(
    @slide.Slide::parse(slide_of_picture(pic).serialize()).serialize(),
  )
  // A non-empty `<p:nvPr>…</p:nvPr>` (the buggy form emitted a self-closed
  // `<p:nvPr/>`, so `<p:nvPr>` with a `>` would be absent).
  let nvpr_open = char_index_of(xml, "<p:nvPr>")
  let nvpr_close = char_index_of(xml, "</p:nvPr>")
  assert_true(nvpr_open >= 0)
  assert_true(nvpr_close > nvpr_open)
  // Both the media reference and the p14:media extLst live between them.
  let video = char_index_of(xml, "<a:videoFile")
  let media_ext = char_index_of(xml, @oxml.media_ext_uri)
  assert_true(video > nvpr_open && video < nvpr_close)
  assert_true(media_ext > nvpr_open && media_ext < nvpr_close)
}
