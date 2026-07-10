// Online / URL video embedding.
//
// An online video (YouTube, Vimeo, or any web URL) is the same `<p:pic>` as an
// embedded media clip, but the two media relationships are `External` and
// point at the web URL instead of an in-package media part. So there is *no*
// `/ppt/media/mediaN.*` part — only the poster-frame image — and the
// `<a:videoFile r:link>` + `<p14:media r:embed>` both target the URL. We reuse
// `Picture::of_media` (the exact same shape structure) for the spPr / nvPr.

///|
/// Insert an online video (any web URL) as a media `Picture` on the slide at
/// `slide_idx`. `video_url` is the streaming/web target stored verbatim in the
/// `<a:videoFile>` / `<p14:media>` relationships (`TargetMode=External`);
/// `poster_bytes` is the raster preview frame (PNG / JPEG / …) shown before
/// playback. `(x, y)` / `(cx, cy)` are the EMU position and extent. Raises
/// `Malformed` if `video_url` is empty or the poster isn't a recognised image.
///
/// For YouTube share/watch links use `add_youtube_video_mut`, which normalises
/// the URL to the embeddable `/embed/<id>` form PowerPoint expects.
pub fn Presentation::add_online_video_mut(
  self : Presentation,
  slide_idx : Int,
  video_url : String,
  poster_bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  if video_url == "" {
    raise Malformed("add_online_video_mut: empty video URL")
  }
  // Poster must be a recognised raster image (same gate as embedded media).
  let poster_fmt = match @oxml.detect_image_format(poster_bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add_online_video_mut: unrecognised poster image (expected PNG / JPEG / GIF / BMP / TIFF)",
      )
  }
  // Add only the poster part — the video itself lives at the external URL.
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
  self.ensure_default_content_type(
    poster_fmt.extension(),
    poster_fmt.content_type(),
  )
  // Three relationships from the slide: poster image (Internal), and the
  // video + media links (External, both pointing at the web URL).
  let slide_parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "add_online_video_mut: slide_idx " +
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
  let rels2 = rels1.with_relationship(@opc.Relationship::{
    id: rid_link,
    rel_type: @opc.rt_video,
    target: video_url,
    target_mode: External,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  let rid_media = next_unused_rid(rels2)
  let rels3 = rels2.with_relationship(@opc.Relationship::{
    id: rid_media,
    rel_type: @opc.rt_media,
    target: video_url,
    target_mode: External,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(slide_name, rels3)
  // Build the media picture (same structure as embedded video) and append it.
  let pic_id = next_picture_shape_id(slide_part)
  let pic = @slide.Picture::of_media(
    pic_id,
    "Online Video " + pic_id.to_string(),
    Video,
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
/// Insert a YouTube video as a media `Picture` on the slide at `slide_idx`.
/// `youtube_url` may be any common form — `watch?v=ID`, `youtu.be/ID`,
/// `youtube.com/embed/ID`, or `youtube.com/shorts/ID` — and is normalised to
/// the embeddable `https://www.youtube.com/embed/ID` URL PowerPoint stores.
/// `poster_bytes` is the preview frame (caller-supplied; no built-in
/// thumbnailer — out of scope per §0). Raises `Malformed` if no video id can
/// be extracted, or the poster isn't a recognised image.
pub fn Presentation::add_youtube_video_mut(
  self : Presentation,
  slide_idx : Int,
  youtube_url : String,
  poster_bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  let embed_url = match youtube_embed_url(youtube_url) {
    Some(u) => u
    None =>
      raise Malformed(
        "add_youtube_video_mut: could not extract a video id from '" +
        youtube_url +
        "'",
      )
  }
  self.add_online_video_mut(slide_idx, embed_url, poster_bytes, x, y, cx, cy)
}

///|
/// Normalise a YouTube URL of any common shape to its embeddable
/// `https://www.youtube.com/embed/<id>` form. Returns `None` when no video id
/// can be located. Recognises `youtu.be/<id>`, `…/embed/<id>`,
/// `…/shorts/<id>`, and `watch?v=<id>` (with arbitrary trailing query params).
fn youtube_embed_url(url : String) -> String? {
  // Markers are tried most-specific first; the id is everything after the
  // marker up to the first URL delimiter.
  for marker in ["/embed/", "/shorts/", "youtu.be/", "v="] {
    match url.find(marker) {
      Some(off) => {
        let rest = url.view(start_offset=off + marker.length()).to_owned()
        let id = cut_at_url_delimiter(rest)
        if id != "" {
          return Some("https://www.youtube.com/embed/" + id)
        }
      }
      None => ()
    }
  }
  None
}

///|
/// Return the prefix of `s` up to (but not including) the first URL delimiter
/// (`&`, `?`, `/`, `#`) — used to peel a clean video id off a URL fragment.
fn cut_at_url_delimiter(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '&' || c == '?' || c == '/' || c == '#' {
      break
    }
    buf.write_char(c)
  }
  buf.to_string()
}
