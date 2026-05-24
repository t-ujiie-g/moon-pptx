// Image-insertion API.
//
// `add_picture_mut(slide_idx, bytes, x, y, cx, cy)` is the
// counterpart of `add_slide_mut` for media: it threads a binary
// image through every place the package needs to track it.
//
//   1. Detect the image format (PNG / JPEG / GIF / BMP / TIFF) from
//      the leading magic bytes, picking the right content type +
//      file extension.
//   2. Allocate the next free `/ppt/media/imageN.{ext}` part name.
//   3. Add the image bytes to the package as a new binary part.
//   4. Register the file extension's content type in
//      `[Content_Types].xml` (as a `Default` entry, the convention
//      PowerPoint uses for media).
//   5. Append an `<Relationship>` from the target slide's `.rels`
//      pointing at the image part, allocating a fresh `rId`.
//   6. Construct a typed `@slide.Picture` shape carrying that rId
//      and append it to the slide's shape tree via `update_slide_mut`.
//
// Anyone who only needs the typed shape value (no OPC plumbing)
// can build a `Picture` directly via `@slide.Picture::of_image`.

///|
/// Insert a binary image as a new `Picture` shape on the slide at
/// `slide_idx`. The image bytes are added as a fresh media part;
/// the picture is appended to the slide's shape tree.
///
/// `slide_idx` is the zero-based index into `Presentation::slides()`.
/// `(x, y)` is the picture's offset on the slide in EMU;
/// `(cx, cy)` its extent. Supported formats: PNG, JPEG, GIF, BMP,
/// TIFF — anything else raises `Malformed`.
pub fn Presentation::add_picture_mut(
  self : Presentation,
  slide_idx : Int,
  bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  // 1. Detect image format from magic bytes.
  let fmt = match detect_image_format(bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add_picture_mut: unrecognised image bytes (expected PNG / JPEG / GIF / BMP / TIFF)",
      )
  }
  // 2. Allocate the next image part name.
  let image_name = self.next_image_part_name(fmt.extension)
  // 3. Add the image bytes as a binary part.
  let image_part = @opc.Part::new(image_name, fmt.content_type, bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(image_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 4. Register the extension's content type if it isn't already
  //    declared. PowerPoint stores image content-types as `Default`
  //    entries (per-extension); duplicate Defaults are tolerated but
  //    we deduplicate anyway.
  let cur_ct = self.pkg.content_types()
  let already_declared = cur_ct.defaults
    .iter()
    .any(fn(kv) { kv.0 == fmt.extension })
  if !already_declared {
    let next_ct = cur_ct.with_default(fmt.extension, fmt.content_type)
    self.pkg.set_content_types(next_ct)
    self.pkg.regenerate_content_types_part() catch {
      e => raise OpcFailure(e.to_string())
    }
  }
  // 5. Append a Relationship from the slide to the image. We have
  //    to know the slide's part name; resolve via the ordered-slide
  //    helper that `slides()` uses internally.
  let slide_parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "add_picture_mut: slide_idx " +
      slide_idx.to_string() +
      " out of range (0.." +
      slide_parts.length().to_string() +
      ")",
    )
  }
  let slide_part = slide_parts[slide_idx]
  let slide_name = slide_part.name
  let slide_rels = self.pkg.relationships_for(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let new_rid = next_unused_rid(slide_rels)
  let updated_rels = slide_rels.with_relationship(@opc.Relationship::{
    id: new_rid,
    rel_type: @opc.rt_image,
    target: relative_target(slide_name, image_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(slide_name, updated_rels)
  // 6. Construct the typed Picture shape and append it.
  let pic_id = next_picture_shape_id(slide_part)
  let pic = @slide.Picture::of_image(
    pic_id,
    "Picture " + pic_id.to_string(),
    new_rid,
    x,
    y,
    cx,
    cy,
  )
  // Re-parse the slide, append, write back.
  let slide_obj = @slide.Slide::parse(slide_part.bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
  let updated_slide = slide_obj.with_shape(Picture(pic))
  self.update_slide_mut(slide_idx, updated_slide)
}

// --- helpers ---

///|
/// Image format detected from magic bytes — carries the OOXML
/// content type and the file extension we'll use for the media
/// part.
priv struct ImageFormat {
  content_type : String
  extension : String
}

///|
/// Inspect the leading bytes of `bytes` and return the matching
/// image format. Recognises PNG / JPEG / GIF / BMP / TIFF.
/// Returns `None` for anything else (caller raises Malformed).
fn detect_image_format(bytes : FixedArray[Byte]) -> ImageFormat? {
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if bytes.length() >= 4 &&
    bytes[0] == b'\x89' &&
    bytes[1] == b'\x50' &&
    bytes[2] == b'\x4E' &&
    bytes[3] == b'\x47' {
    return Some({ content_type: "image/png", extension: "png" })
  }
  // JPEG: FF D8 FF
  if bytes.length() >= 3 &&
    bytes[0] == b'\xFF' &&
    bytes[1] == b'\xD8' &&
    bytes[2] == b'\xFF' {
    return Some({ content_type: "image/jpeg", extension: "jpeg" })
  }
  // GIF: 47 49 46 38 ("GIF8")
  if bytes.length() >= 4 &&
    bytes[0] == b'\x47' &&
    bytes[1] == b'\x49' &&
    bytes[2] == b'\x46' &&
    bytes[3] == b'\x38' {
    return Some({ content_type: "image/gif", extension: "gif" })
  }
  // BMP: 42 4D ("BM")
  if bytes.length() >= 2 && bytes[0] == b'\x42' && bytes[1] == b'\x4D' {
    return Some({ content_type: "image/bmp", extension: "bmp" })
  }
  // TIFF: 49 49 2A 00 (little-endian) or 4D 4D 00 2A (big-endian)
  if bytes.length() >= 4 {
    if bytes[0] == b'\x49' &&
      bytes[1] == b'\x49' &&
      bytes[2] == b'\x2A' &&
      bytes[3] == b'\x00' {
      return Some({ content_type: "image/tiff", extension: "tiff" })
    }
    if bytes[0] == b'\x4D' &&
      bytes[1] == b'\x4D' &&
      bytes[2] == b'\x00' &&
      bytes[3] == b'\x2A' {
      return Some({ content_type: "image/tiff", extension: "tiff" })
    }
  }
  None
}

///|
/// Allocate the next `/ppt/media/imageN.{ext}` part name. Scans the
/// current package for existing image parts and picks the smallest
/// N greater than any existing one.
fn Presentation::next_image_part_name(
  self : Presentation,
  extension : String,
) -> String {
  let mut next = 1
  for p in self.pkg.parts() {
    let n = extract_image_index(p.name)
    if n >= next {
      next = n + 1
    }
  }
  "/ppt/media/image" + next.to_string() + "." + extension
}

///|
/// Parse the integer N out of `/ppt/media/imageN.{ext}`. Returns 0
/// when `name` doesn't match the convention.
fn extract_image_index(name : String) -> Int {
  let prefix = "/ppt/media/image"
  let total = name.length()
  let prefix_len = prefix.length()
  if total <= prefix_len {
    return 0
  }
  let prefix_part = name.view(start_offset=0, end_offset=prefix_len)
  if prefix_part.to_owned() != prefix {
    return 0
  }
  // Find the dot separating index from extension.
  let mut dot_at = -1
  for i in prefix_len..<total {
    if name[i] == '.' {
      dot_at = i
      break
    }
  }
  if dot_at < 0 {
    return 0
  }
  let middle = name.view(start_offset=prefix_len, end_offset=dot_at)
  match @oxml.parse_signed_int(middle.to_owned()) {
    Some(n) => n
    None => 0
  }
}

///|
/// Find a shape id one greater than any existing id on the slide.
/// IDs in OOXML are arbitrary unique-per-slide; we follow PowerPoint's
/// "monotonically increasing" convention.
fn next_picture_shape_id(slide_part : @opc.Part) -> Int {
  // Cheap inspection of the slide XML — scan for `<p:cNvPr id="N"`
  // tokens and take max + 1. Falls back to 100 if parsing fails or
  // no shapes exist; collisions on the slide are not catastrophic
  // (PowerPoint warns but doesn't reject), but avoiding them keeps
  // us closer to what real apps emit.
  let bytes = slide_part.bytes
  let mut max_id = 0
  let needle = "<p:cNvPr id=\""
  let needle_len = needle.length()
  let total = bytes.length()
  let mut i = 0
  while i + needle_len < total {
    let mut matched = true
    for j in 0..<needle_len {
      if bytes[i + j].to_int() != needle[j].to_int() {
        matched = false
        break
      }
    }
    if matched {
      // Read digits until the closing quote.
      let mut k = i + needle_len
      let mut acc = 0
      while k < total && bytes[k] >= b'0' && bytes[k] <= b'9' {
        acc = acc * 10 + (bytes[k].to_int() - b'0'.to_int())
        k = k + 1
      }
      if acc > max_id {
        max_id = acc
      }
      i = k
    } else {
      i = i + 1
    }
  }
  max_id + 1
}
