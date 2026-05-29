// @oxml media-format detection tests (roadmap v0.3 A6).
// Reuses `bytes_of` from image_test.mbt (same blackbox package).

///|
test "detect_media_format: ISO-BMFF brands (mp4 / mov / m4a)" {
  // ...ftyp at offset 4, brand at 8.
  let mp4 = bytes_of([
    0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D,
  ])
  assert_true(@oxml.detect_media_format(mp4) is Some(Mp4))
  let mov = bytes_of([
    0, 0, 0, 0x14, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20,
  ])
  assert_true(@oxml.detect_media_format(mov) is Some(Mov))
  let m4a = bytes_of([
    0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20,
  ])
  assert_true(@oxml.detect_media_format(m4a) is Some(M4a))
}

///|
test "detect_media_format: RIFF (avi / wav)" {
  let avi = bytes_of([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x41, 0x56, 0x49, 0x20,
  ])
  assert_true(@oxml.detect_media_format(avi) is Some(Avi))
  let wav = bytes_of([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45,
  ])
  assert_true(@oxml.detect_media_format(wav) is Some(Wav))
}

///|
test "detect_media_format: aiff / wmv / mp3" {
  let aiff = bytes_of([
    0x46, 0x4F, 0x52, 0x4D, 0, 0, 0, 0, 0x41, 0x49, 0x46, 0x46,
  ])
  assert_true(@oxml.detect_media_format(aiff) is Some(Aiff))
  let wmv = bytes_of([0x30, 0x26, 0xB2, 0x75, 0, 0, 0, 0])
  assert_true(@oxml.detect_media_format(wmv) is Some(Wmv))
  let mp3_id3 = bytes_of([0x49, 0x44, 0x33, 0x03, 0x00])
  assert_true(@oxml.detect_media_format(mp3_id3) is Some(Mp3))
  let mp3_sync = bytes_of([0xFF, 0xFB, 0x90, 0x00])
  assert_true(@oxml.detect_media_format(mp3_sync) is Some(Mp3))
}

///|
test "detect_media_format: unknown bytes → None" {
  assert_true(@oxml.detect_media_format(bytes_of([0, 1, 2, 3, 4, 5])) is None)
}

///|
test "MediaFormat: content_type / extension / is_video" {
  assert_eq((Mp4 : @oxml.MediaFormat).content_type(), "video/mp4")
  assert_eq((Mp4 : @oxml.MediaFormat).extension(), "mp4")
  assert_true((Mp4 : @oxml.MediaFormat).is_video())
  assert_eq((Mp3 : @oxml.MediaFormat).content_type(), "audio/mpeg")
  assert_false((Mp3 : @oxml.MediaFormat).is_video())
  assert_eq((M4a : @oxml.MediaFormat).content_type(), "audio/mp4")
}
