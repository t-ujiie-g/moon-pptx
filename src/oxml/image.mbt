// Magic-byte image detection + pixel-dimension + DPI parsing.
//
// Used by `@presentation.add_picture_mut / add_picture_auto_mut` to
// (a) pick the correct OOXML content type for a media part and
// (b) derive an EMU extent when the caller doesn't supply one.
//
// Each format we support:
//   - PNG  (89 50 4E 47 …)        — IHDR width/height + optional pHYs DPI
//   - JPEG (FF D8 FF …)           — walk markers to SOFn for w/h, APP0 JFIF for DPI
//   - GIF  (47 49 46 38 …)        — fixed-offset 2×u16 LE w/h; no DPI metadata
//   - BMP  (42 4D …)              — DIB header w/h + pixels-per-metre DPI
//   - TIFF (49 49 2A 00 / 4D 4D 00 2A) — IFD walk for w/h + XResolution/YResolution
//
// Default DPI when missing or unparseable: 96.0 (Windows / PowerPoint
// convention). EMU/pixel = 914_400 / dpi.

///|
/// Image format detected from leading magic bytes.
pub(all) enum ImageFormat {
  /// PNG (Portable Network Graphics). Magic: `89 50 4E 47 0D 0A 1A 0A`.
  Png
  /// JPEG / JFIF. Magic: `FF D8 FF`.
  Jpeg
  /// GIF87a / GIF89a. Magic: `47 49 46 38`.
  Gif
  /// Windows Bitmap. Magic: `42 4D` (`"BM"`).
  Bmp
  /// TIFF (little- or big-endian). Magic: `49 49 2A 00` or `4D 4D 00 2A`.
  Tiff
} derive(Eq, Debug)

///|
pub impl Show for ImageFormat with fn output(self, logger) {
  logger.write_string(
    match self {
      Png => "Png"
      Jpeg => "Jpeg"
      Gif => "Gif"
      Bmp => "Bmp"
      Tiff => "Tiff"
    },
  )
}

///|
/// OOXML content type for this image format. PowerPoint declares
/// these as `Default` entries (per-extension) in `[Content_Types].xml`.
pub fn ImageFormat::content_type(self : ImageFormat) -> String {
  match self {
    Png => "image/png"
    Jpeg => "image/jpeg"
    Gif => "image/gif"
    Bmp => "image/bmp"
    Tiff => "image/tiff"
  }
}

///|
/// File extension we use for media parts of this format. PowerPoint
/// is lenient about extensions, but matching the content-type keeps
/// `[Content_Types].xml` consistent.
pub fn ImageFormat::extension(self : ImageFormat) -> String {
  match self {
    Png => "png"
    Jpeg => "jpeg"
    Gif => "gif"
    Bmp => "bmp"
    Tiff => "tiff"
  }
}

///|
/// Inspect the leading bytes of `bytes` and return the matching
/// image format. Returns `None` for anything else.
pub fn detect_image_format(bytes : FixedArray[Byte]) -> ImageFormat? {
  let n = bytes.length()
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if n >= 4 &&
    bytes[0] == b'\x89' &&
    bytes[1] == b'\x50' &&
    bytes[2] == b'\x4E' &&
    bytes[3] == b'\x47' {
    return Some(Png)
  }
  // JPEG: FF D8 FF
  if n >= 3 && bytes[0] == b'\xFF' && bytes[1] == b'\xD8' && bytes[2] == b'\xFF' {
    return Some(Jpeg)
  }
  // GIF: 47 49 46 38 ("GIF8")
  if n >= 4 &&
    bytes[0] == b'\x47' &&
    bytes[1] == b'\x49' &&
    bytes[2] == b'\x46' &&
    bytes[3] == b'\x38' {
    return Some(Gif)
  }
  // BMP: 42 4D ("BM")
  if n >= 2 && bytes[0] == b'\x42' && bytes[1] == b'\x4D' {
    return Some(Bmp)
  }
  // TIFF: II 2A 00 (LE) or MM 00 2A (BE)
  if n >= 4 {
    if bytes[0] == b'\x49' &&
      bytes[1] == b'\x49' &&
      bytes[2] == b'\x2A' &&
      bytes[3] == b'\x00' {
      return Some(Tiff)
    }
    if bytes[0] == b'\x4D' &&
      bytes[1] == b'\x4D' &&
      bytes[2] == b'\x00' &&
      bytes[3] == b'\x2A' {
      return Some(Tiff)
    }
  }
  None
}

///|
/// Pixel-space dimensions of an image plus the DPI hints needed to
/// convert to EMU. `dpi_x` / `dpi_y` default to 96.0 when the file
/// carries no metadata.
pub(all) struct ImageDimensions {
  /// Detected image format (matches `detect_image_format`).
  format : ImageFormat
  /// Image width in pixels.
  width_px : Int
  /// Image height in pixels.
  height_px : Int
  /// Horizontal DPI (dots per inch). 96.0 when the file omits it.
  dpi_x : Double
  /// Vertical DPI (dots per inch). 96.0 when the file omits it.
  dpi_y : Double
} derive(Eq, Debug)

///|
pub impl Show for ImageDimensions with fn output(self, logger) {
  logger.write_string("ImageDimensions(")
  self.format.output(logger)
  logger.write_string(" ")
  logger.write_string(self.width_px.to_string())
  logger.write_string("x")
  logger.write_string(self.height_px.to_string())
  logger.write_string("px @ ")
  logger.write_string(self.dpi_x.to_string())
  logger.write_string("/")
  logger.write_string(self.dpi_y.to_string())
  logger.write_string("dpi)")
}

///|
/// Convert pixel dimensions to EMU using the embedded DPI hints.
/// EMU/pixel = 914_400 / dpi. Returns `(cx_emu, cy_emu)`.
pub fn ImageDimensions::to_emu(self : ImageDimensions) -> (Int64, Int64) {
  let emu_per_inch = 914400.0
  let cx = (self.width_px.to_double() * emu_per_inch / self.dpi_x).to_int64()
  let cy = (self.height_px.to_double() * emu_per_inch / self.dpi_y).to_int64()
  (cx, cy)
}

///|
/// Parse `bytes` as a supported image format and return its pixel
/// dimensions + DPI hints. Returns `None` if the format isn't one
/// of PNG / JPEG / GIF / BMP / TIFF, or if the file is too short
/// or malformed to extract dimensions.
pub fn detect_image_dimensions(bytes : FixedArray[Byte]) -> ImageDimensions? {
  match detect_image_format(bytes) {
    Some(Png) => detect_png_dimensions(bytes)
    Some(Jpeg) => detect_jpeg_dimensions(bytes)
    Some(Gif) => detect_gif_dimensions(bytes)
    Some(Bmp) => detect_bmp_dimensions(bytes)
    Some(Tiff) => detect_tiff_dimensions(bytes)
    None => None
  }
}

// --- per-format dimension extractors ---

///|
/// PNG IHDR is always the first chunk after the 8-byte signature.
/// Layout: 4-byte length, "IHDR", then 13 bytes of which the first 8
/// are width + height (big-endian uint32 each).
/// pHYs chunk (if present) carries pixels-per-metre × 2 + unit byte.
fn detect_png_dimensions(bytes : FixedArray[Byte]) -> ImageDimensions? {
  let n = bytes.length()
  if n < 24 {
    return None
  }
  let w = u32_be(bytes, 16)
  let h = u32_be(bytes, 20)
  // Default DPI; overwritten if we find pHYs.
  let mut dpi_x = 96.0
  let mut dpi_y = 96.0
  // Scan chunks from byte 8 onward looking for "pHYs". Each chunk:
  // 4-byte length, 4-byte type, length bytes data, 4-byte CRC.
  let mut i = 8
  while i + 8 <= n {
    let chunk_len = u32_be(bytes, i)
    if chunk_len < 0 || i + 8 + chunk_len + 4 > n {
      break
    }
    let type_eq = bytes[i + 4] == b'p' &&
      bytes[i + 5] == b'H' &&
      bytes[i + 6] == b'Y' &&
      bytes[i + 7] == b's'
    if type_eq && chunk_len >= 9 {
      let ppu_x = u32_be(bytes, i + 8)
      let ppu_y = u32_be(bytes, i + 12)
      let unit = bytes[i + 16]
      // unit=1 means "metre". Convert ppm → dpi via inches-per-metre.
      if unit == b'\x01' && ppu_x > 0 && ppu_y > 0 {
        dpi_x = ppu_x.to_double() * 0.0254
        dpi_y = ppu_y.to_double() * 0.0254
      }
      break
    }
    // "IEND" marks end-of-file; stop scanning early.
    if bytes[i + 4] == b'I' &&
      bytes[i + 5] == b'E' &&
      bytes[i + 6] == b'N' &&
      bytes[i + 7] == b'D' {
      break
    }
    i = i + 8 + chunk_len + 4
  }
  Some({ format: Png, width_px: w, height_px: h, dpi_x, dpi_y })
}

///|
/// JPEG: walk segment markers from byte 2 (after SOI 0xFFD8) looking
/// for an SOFn marker that carries dimensions, optionally noting an
/// APP0 JFIF segment for DPI on the way.
fn detect_jpeg_dimensions(bytes : FixedArray[Byte]) -> ImageDimensions? {
  let n = bytes.length()
  if n < 4 {
    return None
  }
  let mut i = 2
  let mut dpi_x = 96.0
  let mut dpi_y = 96.0
  while i + 4 <= n {
    if bytes[i] != b'\xFF' {
      return None
    }
    // Walk past fill bytes (multiple 0xFF allowed).
    while i + 1 < n && bytes[i + 1] == b'\xFF' {
      i = i + 1
    }
    if i + 1 >= n {
      return None
    }
    let marker = bytes[i + 1]
    i = i + 2
    // Standalone markers without a payload: 0xD0..0xD9 + 0x01 — skip.
    if marker == b'\xD8' ||
      marker == b'\xD9' ||
      marker == b'\x01' ||
      (marker.to_int() >= 0xD0 && marker.to_int() <= 0xD7) {
      continue
    }
    if i + 2 > n {
      return None
    }
    let seg_len = u16_be(bytes, i) // includes the length bytes themselves
    if seg_len < 2 || i + seg_len > n {
      return None
    }
    let m = marker.to_int()
    // SOFn: C0–C3, C5–C7, C9–CB, CD–CF (skip C4, C8, CC which are tables / DAC).
    let is_sof = (m >= 0xC0 && m <= 0xC3) ||
      (m >= 0xC5 && m <= 0xC7) ||
      (m >= 0xC9 && m <= 0xCB) ||
      (m >= 0xCD && m <= 0xCF)
    if is_sof {
      if seg_len < 7 {
        return None
      }
      // After length(2): precision(1), height(2), width(2).
      let h = u16_be(bytes, i + 3)
      let w = u16_be(bytes, i + 5)
      return Some({ format: Jpeg, width_px: w, height_px: h, dpi_x, dpi_y })
    }
    // APP0 (E0) JFIF segment — read DPI.
    if marker == b'\xE0' && seg_len >= 14 {
      // identifier "JFIF\0"
      if bytes[i + 2] == b'J' &&
        bytes[i + 3] == b'F' &&
        bytes[i + 4] == b'I' &&
        bytes[i + 5] == b'F' &&
        bytes[i + 6] == b'\x00' {
        let unit = bytes[i + 9]
        let dx = u16_be(bytes, i + 10).to_double()
        let dy = u16_be(bytes, i + 12).to_double()
        if dx > 0.0 && dy > 0.0 {
          if unit == b'\x01' {
            // dots per inch — use directly
            dpi_x = dx
            dpi_y = dy
          } else if unit == b'\x02' {
            // dots per cm → dpi
            dpi_x = dx * 2.54
            dpi_y = dy * 2.54
          }
          // unit=0 means "aspect-ratio only"; leave defaults.
        }
      }
    }
    i = i + seg_len
  }
  None
}

///|
/// GIF: bytes 6..=9 hold logical-screen width + height (uint16 LE).
fn detect_gif_dimensions(bytes : FixedArray[Byte]) -> ImageDimensions? {
  if bytes.length() < 10 {
    return None
  }
  let w = u16_le(bytes, 6)
  let h = u16_le(bytes, 8)
  Some({ format: Gif, width_px: w, height_px: h, dpi_x: 96.0, dpi_y: 96.0 })
}

///|
/// BMP: DIB header starts at byte 14. For the common BITMAPINFOHEADER
/// (size = 40), width is i32 at offset 18 and height is i32 at offset
/// 22 (negative height means top-down). DPI lives at offsets 38, 42
/// as pixels-per-metre.
fn detect_bmp_dimensions(bytes : FixedArray[Byte]) -> ImageDimensions? {
  let n = bytes.length()
  if n < 26 {
    return None
  }
  let dib_size = u32_le(bytes, 14)
  let w_signed = u32_le(bytes, 18)
  let h_signed = u32_le(bytes, 22)
  let w = if w_signed >= 0 { w_signed } else { -w_signed }
  let h = if h_signed >= 0 { h_signed } else { -h_signed }
  let mut dpi_x = 96.0
  let mut dpi_y = 96.0
  // BITMAPINFOHEADER + variants carry pixels-per-metre at offset 38/42.
  if dib_size >= 40 && n >= 46 {
    let ppm_x = u32_le(bytes, 38)
    let ppm_y = u32_le(bytes, 42)
    if ppm_x > 0 && ppm_y > 0 {
      dpi_x = ppm_x.to_double() * 0.0254
      dpi_y = ppm_y.to_double() * 0.0254
    }
  }
  Some({ format: Bmp, width_px: w, height_px: h, dpi_x, dpi_y })
}

///|
/// TIFF: minimal IFD walk for ImageWidth (tag 256), ImageLength
/// (tag 257), XResolution (282), YResolution (283), ResolutionUnit
/// (296). We only honour the first IFD.
fn detect_tiff_dimensions(bytes : FixedArray[Byte]) -> ImageDimensions? {
  let n = bytes.length()
  if n < 8 {
    return None
  }
  let little = bytes[0] == b'\x49'
  let read_u16 = if little { u16_le } else { u16_be }
  let read_u32 = if little { u32_le } else { u32_be }
  let ifd_offset = read_u32(bytes, 4)
  if ifd_offset < 8 || ifd_offset + 2 > n {
    return None
  }
  let entry_count = read_u16(bytes, ifd_offset)
  let base = ifd_offset + 2
  if base + entry_count * 12 > n {
    return None
  }
  let mut width = 0
  let mut height = 0
  let mut x_res_num = 0
  let mut x_res_den = 1
  let mut y_res_num = 0
  let mut y_res_den = 1
  let mut res_unit = 2 // default = inch
  for k in 0..<entry_count {
    let e = base + k * 12
    let tag = read_u16(bytes, e)
    let typ = read_u16(bytes, e + 2)
    // Short value (type 3) fits in the value field; long (type 4) too.
    // Rational (type 5) is two u32s at the offset in the value field.
    if tag == 256 {
      width = if typ == 3 {
        read_u16(bytes, e + 8)
      } else {
        read_u32(bytes, e + 8)
      }
    } else if tag == 257 {
      height = if typ == 3 {
        read_u16(bytes, e + 8)
      } else {
        read_u32(bytes, e + 8)
      }
    } else if tag == 296 {
      res_unit = read_u16(bytes, e + 8)
    } else if tag == 282 && typ == 5 {
      let off = read_u32(bytes, e + 8)
      if off + 8 <= n {
        x_res_num = read_u32(bytes, off)
        x_res_den = read_u32(bytes, off + 4)
      }
    } else if tag == 283 && typ == 5 {
      let off = read_u32(bytes, e + 8)
      if off + 8 <= n {
        y_res_num = read_u32(bytes, off)
        y_res_den = read_u32(bytes, off + 4)
      }
    }
  }
  if width <= 0 || height <= 0 {
    return None
  }
  let mut dpi_x = 96.0
  let mut dpi_y = 96.0
  if x_res_num > 0 && x_res_den > 0 && y_res_num > 0 && y_res_den > 0 {
    let x_rate = x_res_num.to_double() / x_res_den.to_double()
    let y_rate = y_res_num.to_double() / y_res_den.to_double()
    if res_unit == 2 {
      // Already DPI.
      dpi_x = x_rate
      dpi_y = y_rate
    } else if res_unit == 3 {
      // Per centimetre → dpi.
      dpi_x = x_rate * 2.54
      dpi_y = y_rate * 2.54
    }
    // res_unit == 1 means "no absolute unit"; defaults stay.
  }
  Some({ format: Tiff, width_px: width, height_px: height, dpi_x, dpi_y })
}

// --- byte readers ---

///|
fn u16_be(bytes : FixedArray[Byte], offset : Int) -> Int {
  bytes[offset].to_int() * 256 + bytes[offset + 1].to_int()
}

///|
fn u16_le(bytes : FixedArray[Byte], offset : Int) -> Int {
  bytes[offset].to_int() + bytes[offset + 1].to_int() * 256
}

///|
fn u32_be(bytes : FixedArray[Byte], offset : Int) -> Int {
  (bytes[offset].to_int() << 24) |
  (bytes[offset + 1].to_int() << 16) |
  (bytes[offset + 2].to_int() << 8) |
  bytes[offset + 3].to_int()
}

///|
/// Read a 32-bit little-endian integer. MoonBit's `Int` is 32-bit
/// two's-complement, so this doubles as the signed reader (an i32
/// "negative height" BMP top-down marker comes back as negative
/// automatically).
fn u32_le(bytes : FixedArray[Byte], offset : Int) -> Int {
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}
