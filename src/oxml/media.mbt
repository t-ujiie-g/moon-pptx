// Audio / video format detection from magic bytes.
//
// Mirrors `image.mbt`'s `detect_image_format`: inspect leading bytes, pick
// the content type + file extension PowerPoint expects for the media part.

///|
/// A recognised embeddable media format. Video: `Mp4` / `Mov` / `Avi` /
/// `Wmv`. Audio: `Mp3` / `Wav` / `Aiff` / `M4a`.
pub(all) enum MediaFormat {
  Mp4
  Mov
  Avi
  Wmv
  Mp3
  Wav
  Aiff
  M4a
} derive(Eq, Debug)

///|
pub impl Show for MediaFormat with fn output(self, logger) {
  logger.write_string(
    match self {
      Mp4 => "Mp4"
      Mov => "Mov"
      Avi => "Avi"
      Wmv => "Wmv"
      Mp3 => "Mp3"
      Wav => "Wav"
      Aiff => "Aiff"
      M4a => "M4a"
    },
  )
}

///|
/// MIME content type, registered as a per-extension `Default` in
/// `[Content_Types].xml` (the convention PowerPoint uses for media).
pub fn MediaFormat::content_type(self : MediaFormat) -> String {
  match self {
    Mp4 => "video/mp4"
    Mov => "video/quicktime"
    Avi => "video/avi"
    Wmv => "video/x-ms-wmv"
    Mp3 => "audio/mpeg"
    Wav => "audio/wav"
    Aiff => "audio/aiff"
    M4a => "audio/mp4"
  }
}

///|
/// File extension for the media part (`/ppt/media/mediaN.{ext}`).
pub fn MediaFormat::extension(self : MediaFormat) -> String {
  match self {
    Mp4 => "mp4"
    Mov => "mov"
    Avi => "avi"
    Wmv => "wmv"
    Mp3 => "mp3"
    Wav => "wav"
    Aiff => "aiff"
    M4a => "m4a"
  }
}

///|
/// Whether this format is a video (vs audio). Drives whether the builder
/// emits `<a:videoFile>` or `<a:audioFile>`.
pub fn MediaFormat::is_video(self : MediaFormat) -> Bool {
  match self {
    Mp4 | Mov | Avi | Wmv => true
    Mp3 | Wav | Aiff | M4a => false
  }
}

///|
/// True if the four bytes at `off` equal `(a, b, c, d)`.
fn tag_at(
  bytes : FixedArray[Byte],
  off : Int,
  a : Int,
  b : Int,
  c : Int,
  d : Int,
) -> Bool {
  bytes.length() >= off + 4 &&
  bytes[off].to_int() == a &&
  bytes[off + 1].to_int() == b &&
  bytes[off + 2].to_int() == c &&
  bytes[off + 3].to_int() == d
}

///|
/// Inspect the leading bytes of `bytes` and return the matching media
/// format, or `None`. Recognises MP4/MOV/M4A (ISO-BMFF `ftyp`),
/// AVI / WAV (RIFF), WMV (ASF), MP3 (`ID3` tag or MPEG frame sync), and
/// AIFF (`FORM…AIFF`).
pub fn detect_media_format(bytes : FixedArray[Byte]) -> MediaFormat? {
  let n = bytes.length()
  // ISO base media (mp4 / mov / m4a): "ftyp" box at offset 4, brand at 8.
  if tag_at(bytes, 4, 0x66, 0x74, 0x79, 0x70) {
    // "qt  " brand → QuickTime.
    if tag_at(bytes, 8, 0x71, 0x74, 0x20, 0x20) {
      return Some(Mov)
    }
    // "M4A " brand → audio-only MPEG-4.
    if tag_at(bytes, 8, 0x4D, 0x34, 0x41, 0x20) {
      return Some(M4a)
    }
    return Some(Mp4)
  }
  // RIFF container: "RIFF" at 0, sub-format at 8.
  if tag_at(bytes, 0, 0x52, 0x49, 0x46, 0x46) {
    if tag_at(bytes, 8, 0x41, 0x56, 0x49, 0x20) {
      return Some(Avi) // "AVI "
    }
    if tag_at(bytes, 8, 0x57, 0x41, 0x56, 0x45) {
      return Some(Wav) // "WAVE"
    }
  }
  // AIFF: "FORM" at 0, "AIFF" at 8.
  if tag_at(bytes, 0, 0x46, 0x4F, 0x52, 0x4D) &&
    tag_at(bytes, 8, 0x41, 0x49, 0x46, 0x46) {
    return Some(Aiff)
  }
  // ASF / WMV: GUID prefix 30 26 B2 75.
  if tag_at(bytes, 0, 0x30, 0x26, 0xB2, 0x75) {
    return Some(Wmv)
  }
  // MP3: "ID3" tag, or an MPEG audio frame sync (0xFF Ex/Fx).
  if n >= 3 &&
    bytes[0].to_int() == 0x49 &&
    bytes[1].to_int() == 0x44 &&
    bytes[2].to_int() == 0x33 {
    return Some(Mp3)
  }
  if n >= 2 && bytes[0].to_int() == 0xFF && (bytes[1].to_int() & 0xE0) == 0xE0 {
    return Some(Mp3)
  }
  None
}
