// Audio / video embedding (roadmap v0.3 A6).
//
// An embedded media clip is a `<p:pic>` that references the media part three
// ways: an `<a:videoFile>` / `<a:audioFile>` (`r:link`, the video/audio
// relationship), a `<p14:media>` (`r:embed`, the Office 2007 media
// relationship), and a poster-frame image in `<p:blipFill>`. We wire the two
// parts (media + poster) and three relationships here, then build the typed
// `@slide.Picture` via `Picture::of_media`.

///|
/// Insert a video as a media `Picture` on the slide at `slide_idx`.
/// `video_bytes` is the clip (MP4 / MOV / AVI / WMV — detected from magic
/// bytes); `poster_bytes` is a raster image (PNG / JPEG / …) shown as the
/// still frame before playback. `(x, y)` / `(cx, cy)` are the EMU position
/// and extent. Raises `Malformed` if the bytes aren't a recognised video, or
/// the poster isn't a recognised image.
pub fn Presentation::add_video_mut(
  self : Presentation,
  slide_idx : Int,
  video_bytes : FixedArray[Byte],
  poster_bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  let fmt = match @oxml.detect_media_format(video_bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add_video_mut: unrecognised media bytes (expected MP4 / MOV / AVI / WMV)",
      )
  }
  if !fmt.is_video() {
    raise Malformed(
      "add_video_mut: bytes are an audio format (" +
      fmt.to_string() +
      "); use add_audio_mut",
    )
  }
  self.add_media_mut(
    slide_idx,
    video_bytes,
    fmt,
    Video,
    poster_bytes,
    x,
    y,
    cx,
    cy,
  )
}

///|
/// Insert an audio clip as a media `Picture` on the slide at `slide_idx`.
/// `audio_bytes` is the clip (MP3 / WAV / AIFF / M4A); `poster_bytes` is the
/// image shown for it (e.g. a speaker icon). Otherwise like `add_video_mut`.
pub fn Presentation::add_audio_mut(
  self : Presentation,
  slide_idx : Int,
  audio_bytes : FixedArray[Byte],
  poster_bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  let fmt = match @oxml.detect_media_format(audio_bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add_audio_mut: unrecognised media bytes (expected MP3 / WAV / AIFF / M4A)",
      )
  }
  if fmt.is_video() {
    raise Malformed(
      "add_audio_mut: bytes are a video format (" +
      fmt.to_string() +
      "); use add_video_mut",
    )
  }
  self.add_media_mut(
    slide_idx,
    audio_bytes,
    fmt,
    Audio,
    poster_bytes,
    x,
    y,
    cx,
    cy,
  )
}

///|
/// Shared media-insertion pipeline behind `add_video_mut` / `add_audio_mut`.
/// Adds the media part + poster part, the three relationships
/// (`image` for the poster, `video`/`audio` for the link, `media` for the
/// embed), the content-type defaults, and the `Picture::of_media` shape.
fn Presentation::add_media_mut(
  self : Presentation,
  slide_idx : Int,
  media_bytes : FixedArray[Byte],
  fmt : @oxml.MediaFormat,
  kind : @slide.MediaKind,
  poster_bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  // Poster must be a recognised raster image.
  let poster_fmt = match @oxml.detect_image_format(poster_bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add media: unrecognised poster image (expected PNG / JPEG / GIF / BMP / TIFF)",
      )
  }
  // Add the media part, then the poster part.
  let media_name = self.next_media_part_name(fmt.extension())
  let media_part = @opc.Part::new(media_name, fmt.content_type(), media_bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(media_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  let poster_name = self.next_image_part_name(poster_fmt.extension())
  let poster_part = @opc.Part::new(
    poster_name,
    poster_fmt.content_type(),
    poster_bytes,
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(poster_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // Content-type Defaults for both extensions.
  self.ensure_default_content_type(fmt.extension(), fmt.content_type())
  self.ensure_default_content_type(
    poster_fmt.extension(),
    poster_fmt.content_type(),
  )
  // Three relationships from the slide: poster image, media link, media embed.
  let slide_parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "add media: slide_idx " +
      slide_idx.to_string() +
      " out of range (0.." +
      slide_parts.length().to_string() +
      ")",
    )
  }
  let slide_part = slide_parts[slide_idx]
  let slide_name = slide_part.name
  let rels0 = self.pkg.relationships_for(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let rid_poster = next_unused_rid(rels0)
  let rels1 = rels0.with_relationship(@opc.Relationship::{
    id: rid_poster,
    rel_type: @opc.rt_image,
    target: relative_target(slide_name, poster_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  let rid_link = next_unused_rid(rels1)
  let link_rel_type = match kind {
    Video => @opc.rt_video
    Audio => @opc.rt_audio
  }
  let rels2 = rels1.with_relationship(@opc.Relationship::{
    id: rid_link,
    rel_type: link_rel_type,
    target: relative_target(slide_name, media_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  let rid_media = next_unused_rid(rels2)
  let rels3 = rels2.with_relationship(@opc.Relationship::{
    id: rid_media,
    rel_type: @opc.rt_media,
    target: relative_target(slide_name, media_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(slide_name, rels3)
  // Build the media picture and append it.
  let pic_id = next_picture_shape_id(slide_part)
  let pic = @slide.Picture::of_media(
    pic_id,
    "Media " + pic_id.to_string(),
    kind,
    rid_link,
    rid_media,
    rid_poster,
    x,
    y,
    cx,
    cy,
  )
  let slide_obj = @slide.Slide::parse(slide_part.bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
  self.update_slide_mut(slide_idx, slide_obj.with_shape(Picture(pic)))
}

///|
/// Allocate the next `/ppt/media/mediaN.{ext}` part name (parallel to
/// `next_image_part_name`, but for the `mediaN` audio/video parts).
fn Presentation::next_media_part_name(
  self : Presentation,
  extension : String,
) -> String {
  "/ppt/media/media" +
  (self.max_part_index("/ppt/media/media") + 1).to_string() +
  "." +
  extension
}
