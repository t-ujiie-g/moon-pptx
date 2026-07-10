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
  let fmt = match @oxml.detect_image_format(bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add_picture_mut: unrecognised image bytes (expected PNG / JPEG / GIF / BMP / TIFF)",
      )
  }
  // 2. Allocate the next image part name.
  let image_name = self.next_image_part_name(fmt.extension())
  // 3. Add the image bytes as a binary part.
  let image_part = @opc.Part::new(image_name, fmt.content_type(), bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(image_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 4. Register the extension's content type if it isn't already
  //    declared. PowerPoint stores image content-types as `Default`
  //    entries (per-extension).
  self.ensure_default_content_type(fmt.extension(), fmt.content_type())
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

///|
/// Like `add_picture_mut` but auto-derives `(cx, cy)` from the image's
/// pixel dimensions + DPI metadata. The default DPI is 96 when the
/// file omits it; this matches PowerPoint's behaviour for raw image
/// insertion.
///
/// Raises `Malformed` if `bytes` isn't a recognised PNG / JPEG /
/// GIF / BMP / TIFF, or if the file is too short to parse dimensions.
pub fn Presentation::add_picture_auto_mut(
  self : Presentation,
  slide_idx : Int,
  bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
) -> Unit raise PptxError {
  let dims = match @oxml.detect_image_dimensions(bytes) {
    Some(d) => d
    None =>
      raise Malformed(
        "add_picture_auto_mut: cannot parse image dimensions (expected PNG / JPEG / GIF / BMP / TIFF with a readable header)",
      )
  }
  let (cx, cy) = dims.to_emu()
  self.add_picture_mut(slide_idx, bytes, x, y, @units.Emu(cx), @units.Emu(cy))
}

///|
/// Insert an SVG image as a new `Picture` shape on the slide at
/// `slide_idx`, with a raster fallback. `svg_bytes` is the
/// SVG part; `fallback_bytes` is a PNG / JPEG / GIF / BMP / TIFF rendering
/// shown by viewers that don't understand SVG (PowerPoint < 2016,
/// thumbnails). The picture's `<a:blip>` embeds the fallback and carries an
/// `<asvg:svgBlip>` extension pointing at the SVG.
///
/// `(x, y)` is the offset in EMU; `(cx, cy)` the extent. Raises `Malformed`
/// if `fallback_bytes` isn't a recognised raster image.
pub fn Presentation::add_svg_picture_mut(
  self : Presentation,
  slide_idx : Int,
  svg_bytes : FixedArray[Byte],
  fallback_bytes : FixedArray[Byte],
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  // 1. The fallback must be a recognised raster image.
  let fmt = match @oxml.detect_image_format(fallback_bytes) {
    Some(f) => f
    None =>
      raise Malformed(
        "add_svg_picture_mut: unrecognised fallback image bytes (expected PNG / JPEG / GIF / BMP / TIFF)",
      )
  }
  // 2. Add both media parts. The fallback goes first so the SVG part name
  //    picks the next index after it.
  let fallback_name = self.next_image_part_name(fmt.extension())
  let fallback_part = @opc.Part::new(
    fallback_name,
    fmt.content_type(),
    fallback_bytes,
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(fallback_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  let svg_name = self.next_image_part_name("svg")
  let svg_part = @opc.Part::new(svg_name, @oxml.ct_svg, svg_bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(svg_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 3. Register both content types (Default per-extension entries).
  self.ensure_default_content_type(fmt.extension(), fmt.content_type())
  self.ensure_default_content_type("svg", @oxml.ct_svg)
  // 4. Two relationships from the slide: fallback (blip embed) + svg.
  let slide_parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "add_svg_picture_mut: slide_idx " +
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
  let rid_png = next_unused_rid(rels0)
  let rels1 = rels0.with_relationship(@opc.Relationship::{
    id: rid_png,
    rel_type: @opc.rt_image,
    target: relative_target(slide_name, fallback_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  let rid_svg = next_unused_rid(rels1)
  let rels2 = rels1.with_relationship(@opc.Relationship::{
    id: rid_svg,
    rel_type: @opc.rt_image,
    target: relative_target(slide_name, svg_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(slide_name, rels2)
  // 5. Construct the typed SVG Picture and append it.
  let pic_id = next_picture_shape_id(slide_part)
  let pic = @slide.Picture::of_svg_image(
    pic_id,
    "Picture " + pic_id.to_string(),
    rid_png,
    rid_svg,
    x,
    y,
    cx,
    cy,
  )
  let slide_obj = @slide.Slide::parse(slide_part.bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
  let updated_slide = slide_obj.with_shape(Picture(pic))
  self.update_slide_mut(slide_idx, updated_slide)
}

// --- helpers ---

///|
/// Declare a per-extension `Default` content-type entry if it isn't
/// already present. PowerPoint stores media content-types this way;
/// duplicate Defaults are tolerated, but we deduplicate anyway.
fn Presentation::ensure_default_content_type(
  self : Presentation,
  ext : String,
  ct : String,
) -> Unit raise PptxError {
  let cur = self.pkg.content_types()
  if !cur.defaults.iter().any(fn(kv) { kv.0 == ext }) {
    self.pkg.set_content_types(cur.with_default(ext, ct))
    self.pkg.regenerate_content_types_part() catch {
      e => raise OpcFailure(e.to_string())
    }
  }
}

///|
/// Allocate the next `/ppt/media/imageN.{ext}` part name, one past the
/// highest existing N (shared scanner: `max_part_index`).
fn Presentation::next_image_part_name(
  self : Presentation,
  extension : String,
) -> String {
  "/ppt/media/image" +
  (self.max_part_index("/ppt/media/image") + 1).to_string() +
  "." +
  extension
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
