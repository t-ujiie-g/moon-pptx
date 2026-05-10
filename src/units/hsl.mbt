// HSL color and RGB ↔ HSL conversion.
//
// OOXML's `CT_HslColor` carries:
//   * `hue`: ST_PositiveFixedAngle (1/60_000 degree)
//   * `sat`: ST_Percentage          (1/1_000 percent)
//   * `lum`: ST_Percentage          (1/1_000 percent)
//
// We store the user-facing values as `Double` (degrees, percent, percent) and
// leave conversion to the OOXML wire format to the serializer layer (it can
// reuse `Angle::to_ooxml()` / `Percentage::to_ooxml()` from this package).

///|
/// HSL color. `hue` is in degrees [0, 360); `saturation` and `lightness` in
/// percent [0, 100]. Out-of-range values round-trip but conversion to RGB
/// clamps `lightness`/`saturation` to [0, 100].
pub(all) struct HslColor {
  hue : Double
  saturation : Double
  lightness : Double
} derive(Debug)

///|
pub fn HslColor::new(
  hue : Double,
  saturation : Double,
  lightness : Double,
) -> HslColor {
  { hue, saturation, lightness }
}

// --- conversions ---

///|
/// Convert RGB to HSL using the standard CSS / OOXML algorithm. Output is in
/// the canonical ranges (hue [0, 360), sat/lum [0, 100]).
pub fn RgbColor::to_hsl(self : RgbColor) -> HslColor {
  let r = self.r.to_double() / 255.0
  let g = self.g.to_double() / 255.0
  let b = self.b.to_double() / 255.0
  let max = max3(r, g, b)
  let min = min3(r, g, b)
  let l = (max + min) / 2.0
  if max == min {
    return { hue: 0.0, saturation: 0.0, lightness: l * 100.0 }
  }
  let delta = max - min
  let s = if l <= 0.5 { delta / (max + min) } else { delta / (2.0 - max - min) }
  let h_raw = if max == r {
    (g - b) / delta + (if g < b { 6.0 } else { 0.0 })
  } else if max == g {
    (b - r) / delta + 2.0
  } else {
    (r - g) / delta + 4.0
  }
  let h = h_raw * 60.0
  { hue: h, saturation: s * 100.0, lightness: l * 100.0 }
}

///|
/// Convert HSL to RGB using the standard CSS / OOXML algorithm. Channel
/// values are rounded to the nearest integer in [0, 255].
pub fn HslColor::to_rgb(self : HslColor) -> RgbColor {
  let h = wrap_hue(self.hue)
  let s = clamp01(self.saturation / 100.0)
  let l = clamp01(self.lightness / 100.0)
  if s == 0.0 {
    let v = round_byte(l * 255.0)
    return { r: v, g: v, b: v }
  }
  let chroma = (1.0 - (2.0 * l - 1.0).abs()) * s
  let h60 = h / 60.0
  let x = chroma * (1.0 - (h60 % 2.0 - 1.0).abs())
  let m = l - chroma / 2.0
  let (rp, gp, bp) = if h60 < 1.0 {
    (chroma, x, 0.0)
  } else if h60 < 2.0 {
    (x, chroma, 0.0)
  } else if h60 < 3.0 {
    (0.0, chroma, x)
  } else if h60 < 4.0 {
    (0.0, x, chroma)
  } else if h60 < 5.0 {
    (x, 0.0, chroma)
  } else {
    (chroma, 0.0, x)
  }
  {
    r: round_byte((rp + m) * 255.0),
    g: round_byte((gp + m) * 255.0),
    b: round_byte((bp + m) * 255.0),
  }
}

// --- helpers ---

///|
fn max3(a : Double, b : Double, c : Double) -> Double {
  let ab = if a > b { a } else { b }
  if ab > c {
    ab
  } else {
    c
  }
}

///|
fn min3(a : Double, b : Double, c : Double) -> Double {
  let ab = if a < b { a } else { b }
  if ab < c {
    ab
  } else {
    c
  }
}

///|
fn clamp01(x : Double) -> Double {
  if x < 0.0 {
    0.0
  } else if x > 1.0 {
    1.0
  } else {
    x
  }
}

///|
fn wrap_hue(h : Double) -> Double {
  let m = h % 360.0
  if m < 0.0 {
    m + 360.0
  } else {
    m
  }
}

///|
fn round_byte(x : Double) -> Int {
  let r = (x + 0.5).to_int()
  if r < 0 {
    0
  } else if r > 255 {
    255
  } else {
    r
  }
}

///|
pub impl Show for HslColor with output(self, logger) {
  logger.write_string("HslColor(")
  logger.write_object(self.hue)
  logger.write_string("deg, ")
  logger.write_object(self.saturation)
  logger.write_string("%, ")
  logger.write_object(self.lightness)
  logger.write_string("%)")
}
