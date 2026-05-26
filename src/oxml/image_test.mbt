// @oxml image detection + dimension parsing tests.

///|
fn bytes_of(values : Array[Int]) -> FixedArray[Byte] {
  let out = FixedArray::make(values.length(), b'\x00')
  let mut i = 0
  while i < values.length() {
    out[i] = values[i].to_byte()
    i = i + 1
  }
  out
}

// --- detect_image_format ---

///|
test "detect_image_format: PNG signature" {
  let b = bytes_of([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
  assert_true(@oxml.detect_image_format(b) is Some(Png))
}

///|
test "detect_image_format: JPEG signature" {
  let b = bytes_of([0xFF, 0xD8, 0xFF, 0xE0])
  assert_true(@oxml.detect_image_format(b) is Some(Jpeg))
}

///|
test "detect_image_format: GIF signature" {
  let b = bytes_of([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
  assert_true(@oxml.detect_image_format(b) is Some(Gif))
}

///|
test "detect_image_format: BMP signature" {
  let b = bytes_of([0x42, 0x4D, 0x00, 0x00])
  assert_true(@oxml.detect_image_format(b) is Some(Bmp))
}

///|
test "detect_image_format: TIFF little-endian signature" {
  let b = bytes_of([0x49, 0x49, 0x2A, 0x00])
  assert_true(@oxml.detect_image_format(b) is Some(Tiff))
}

///|
test "detect_image_format: TIFF big-endian signature" {
  let b = bytes_of([0x4D, 0x4D, 0x00, 0x2A])
  assert_true(@oxml.detect_image_format(b) is Some(Tiff))
}

///|
test "detect_image_format: unknown bytes return None" {
  let b = bytes_of([0x00, 0x01, 0x02, 0x03])
  assert_true(@oxml.detect_image_format(b) is None)
}

///|
test "ImageFormat content_type + extension" {
  assert_eq(@oxml.ImageFormat::Png.content_type(), "image/png")
  assert_eq(@oxml.ImageFormat::Jpeg.content_type(), "image/jpeg")
  assert_eq(@oxml.ImageFormat::Gif.content_type(), "image/gif")
  assert_eq(@oxml.ImageFormat::Bmp.content_type(), "image/bmp")
  assert_eq(@oxml.ImageFormat::Tiff.content_type(), "image/tiff")
  assert_eq(@oxml.ImageFormat::Png.extension(), "png")
  assert_eq(@oxml.ImageFormat::Jpeg.extension(), "jpeg")
  assert_eq(@oxml.ImageFormat::Gif.extension(), "gif")
  assert_eq(@oxml.ImageFormat::Bmp.extension(), "bmp")
  assert_eq(@oxml.ImageFormat::Tiff.extension(), "tiff")
}

// --- PNG dimension tests ---

///|
/// 2×3 PNG, 8-bit RGBA, no pHYs (so DPI falls back to 96).
fn png_2x3_no_phys() -> FixedArray[Byte] {
  bytes_of([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
     0x00, 0x00, 0x00, 0x0D, // IHDR length = 13
     0x49, 0x48, 0x44, 0x52, // "IHDR"
     0x00, 0x00, 0x00, 0x02, // width = 2
     0x00, 0x00, 0x00, 0x03, // height = 3
     0x08, 0x06, 0x00, 0x00, 0x00, // bit depth + color type + compression + filter + interlace
     0x00, 0x00, 0x00, 0x00, // CRC (bogus, the parser doesn't check it)
     0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
     0xAE, 0x42, 0x60, 0x82, // IEND CRC
  ])
}

///|
test "detect_image_dimensions: PNG 2×3, no pHYs → 96 dpi" {
  let d = @oxml.detect_image_dimensions(png_2x3_no_phys()).unwrap()
  assert_true(d.format is Png)
  assert_eq(d.width_px, 2)
  assert_eq(d.height_px, 3)
  assert_eq(d.dpi_x, 96.0)
  assert_eq(d.dpi_y, 96.0)
}

///|
/// 10×20 PNG with a pHYs chunk declaring 300 DPI (300 * 39.3701 ≈
/// 11811 ppm).
fn png_10x20_phys_300dpi() -> FixedArray[Byte] {
  bytes_of([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
     0x00, 0x00, 0x00, 0x0D, // IHDR length
     0x49, 0x48, 0x44, 0x52, // "IHDR"
     0x00, 0x00, 0x00, 0x0A, // width 10
     0x00, 0x00, 0x00, 0x14, // height 20
     0x08, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // CRC
     0x00, 0x00, 0x00, 0x09, // pHYs length = 9
     0x70, 0x48, 0x59, 0x73, // "pHYs"
     0x00, 0x00, 0x2E, 0x23, // ppu_x = 11811 (= 300 dpi × 39.3701)
     0x00, 0x00, 0x2E, 0x23, // ppu_y = 11811
     0x01, // unit = metre
     0x00, 0x00, 0x00, 0x00, // CRC
     0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
     0xAE, 0x42, 0x60, 0x82,
  ])
}

///|
test "detect_image_dimensions: PNG with pHYs lifts DPI" {
  let d = @oxml.detect_image_dimensions(png_10x20_phys_300dpi()).unwrap()
  assert_eq(d.width_px, 10)
  assert_eq(d.height_px, 20)
  // 11811 ppm × 0.0254 = 299.9994 — within rounding tolerance of 300.
  assert_true(d.dpi_x > 299.9 && d.dpi_x < 300.1)
  assert_true(d.dpi_y > 299.9 && d.dpi_y < 300.1)
}

// --- JPEG dimension tests ---

///|
/// Minimal JPEG: SOI + APP0 (JFIF, 96 DPI) + SOF0 (8-bit, 4×7, 3
/// components). Enough for the dimension parser to find SOF0.
fn jpeg_4x7_jfif_96dpi() -> FixedArray[Byte] {
  bytes_of([
    0xFF, 0xD8, // SOI
    // APP0 segment: marker FFE0, length 16, "JFIF\0", v1.01, unit=1 (DPI), 96×96
     0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00,
    0x60, 0x00, 0x60, 0x00, 0x00,
    // SOF0: marker FFC0, length 17, precision 8, height=7, width=4, 3 components × 3 bytes
     0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x07, 0x00, 0x04, 0x03, 0x01, 0x22, 0x00,
    0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xFF, 0xD9, // EOI
  ])
}

///|
test "detect_image_dimensions: JPEG 4×7 @ 96dpi via SOF0+APP0" {
  let d = @oxml.detect_image_dimensions(jpeg_4x7_jfif_96dpi()).unwrap()
  assert_true(d.format is Jpeg)
  assert_eq(d.width_px, 4)
  assert_eq(d.height_px, 7)
  assert_eq(d.dpi_x, 96.0)
  assert_eq(d.dpi_y, 96.0)
}

// --- GIF dimension tests ---

///|
test "detect_image_dimensions: GIF 5×9" {
  let b = bytes_of([
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
     0x05, 0x00, // width 5 (LE)
     0x09, 0x00, // height 9 (LE)
     0x00, 0x00,
  ])
  let d = @oxml.detect_image_dimensions(b).unwrap()
  assert_true(d.format is Gif)
  assert_eq(d.width_px, 5)
  assert_eq(d.height_px, 9)
  // GIF has no DPI; defaults stick.
  assert_eq(d.dpi_x, 96.0)
  assert_eq(d.dpi_y, 96.0)
}

// --- BMP dimension tests ---

///|
test "detect_image_dimensions: BMP 6×4 with BITMAPINFOHEADER" {
  // BITMAPFILEHEADER (14 bytes) + BITMAPINFOHEADER (40 bytes).
  let b = bytes_of([
    0x42, 0x4D, // "BM"
     0x00, 0x00, 0x00, 0x00, // file size (don't care)
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // pixel data offset
     0x28, 0x00, 0x00, 0x00, // DIB header size = 40 (BITMAPINFOHEADER)
     0x06, 0x00, 0x00, 0x00, // width = 6
     0x04, 0x00, 0x00, 0x00, // height = 4
     0x01, 0x00, // planes
     0x18, 0x00, // bpp = 24
     0x00, 0x00, 0x00, 0x00, // compression
     0x00, 0x00, 0x00, 0x00, // image size
     0x13, 0x0B, 0x00, 0x00, // x ppm = 2835 (≈ 72 dpi)
     0x13, 0x0B, 0x00, 0x00, // y ppm = 2835
     0x00, 0x00, 0x00, 0x00, // colors used
     0x00, 0x00, 0x00, 0x00, // important colors
  ])
  let d = @oxml.detect_image_dimensions(b).unwrap()
  assert_true(d.format is Bmp)
  assert_eq(d.width_px, 6)
  assert_eq(d.height_px, 4)
  // 2835 ppm × 0.0254 ≈ 72.009
  assert_true(d.dpi_x > 71.9 && d.dpi_x < 72.1)
}

// --- TIFF dimension tests ---

///|
test "detect_image_dimensions: TIFF little-endian 8×9 (no DPI)" {
  // Header (8) + IFD with 3 entries (width=8, height=9, resolutionUnit=1=none)
  //   entry count u16 + 3 × 12-byte entries + 4-byte next-IFD pointer = 42 bytes
  let b = bytes_of([
    0x49, 0x49, 0x2A, 0x00, // "II" + magic 42
     0x08, 0x00, 0x00, 0x00, // IFD offset = 8
     0x03, 0x00, // entry count = 3
    // entry 1: tag 256 (width), type 3 (short), count 1, value 8
     0x00, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00,
    // entry 2: tag 257 (height), type 3 (short), count 1, value 9
     0x01, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00,
    // entry 3: tag 296 (resolution unit), type 3 (short), count 1, value 1 (= no unit)
     0x28, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, // next IFD = 0
  ])
  let d = @oxml.detect_image_dimensions(b).unwrap()
  assert_true(d.format is Tiff)
  assert_eq(d.width_px, 8)
  assert_eq(d.height_px, 9)
  // resolution unit = no unit → defaults preserved
  assert_eq(d.dpi_x, 96.0)
  assert_eq(d.dpi_y, 96.0)
}

// --- to_emu ---

///|
test "ImageDimensions::to_emu @ 96 dpi" {
  let d : @oxml.ImageDimensions = {
    format: Png,
    width_px: 96,
    height_px: 192,
    dpi_x: 96.0,
    dpi_y: 96.0,
  }
  let (cx, cy) = d.to_emu()
  // 96 px @ 96 dpi = 1 inch = 914_400 EMU.
  assert_eq(cx, 914_400L)
  assert_eq(cy, 1_828_800L)
}

///|
test "ImageDimensions::to_emu @ 300 dpi shrinks output" {
  let d : @oxml.ImageDimensions = {
    format: Png,
    width_px: 300,
    height_px: 600,
    dpi_x: 300.0,
    dpi_y: 300.0,
  }
  let (cx, cy) = d.to_emu()
  // 300 px @ 300 dpi = 1 inch = 914_400 EMU.
  assert_eq(cx, 914_400L)
  assert_eq(cy, 1_828_800L)
}

///|
test "detect_image_dimensions: too-short bytes return None" {
  let b = bytes_of([0x89, 0x50])
  assert_true(@oxml.detect_image_dimensions(b) is None)
}
