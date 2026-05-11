// Scheme color (theme reference + modifiers).
//
// OOXML's `CT_SchemeColor` references one of 17 named theme color slots and
// applies an ordered list of color transforms (tint, shade, modulation, etc).
// The full transform set in ECMA-376 is large; we model the ones used in
// nearly every real-world PPTX and leave the rare ones as a known extension
// point (see TODO.md Phase 1.2 follow-ups).

///|
/// One of the named OOXML theme color slots (ST_SchemeColorVal).
///
/// * `Bg1`/`Bg2`/`Tx1`/`Tx2` are slide-level mappings resolved via the
///   `clrMap` element (master/layout/slide level).
/// * `Dk1`/`Dk2`/`Lt1`/`Lt2` are the master-level definitions referenced
///   by the slide-level mappings.
/// * `Accent1`..`Accent6`, `Hlink`, `FolHlink` are direct theme references.
/// * `PhClr` is the placeholder color used inside style reference resolution.
pub(all) enum ThemeColor {
  Bg1
  Bg2
  Tx1
  Tx2
  Dk1
  Dk2
  Lt1
  Lt2
  Accent1
  Accent2
  Accent3
  Accent4
  Accent5
  Accent6
  Hlink
  FolHlink
  PhClr
} derive(Eq, Debug)

///|
/// Render to the OOXML `val` attribute string (`accent1`, `bg1`, …).
pub fn ThemeColor::to_xml(self : ThemeColor) -> String {
  match self {
    Bg1 => "bg1"
    Bg2 => "bg2"
    Tx1 => "tx1"
    Tx2 => "tx2"
    Dk1 => "dk1"
    Dk2 => "dk2"
    Lt1 => "lt1"
    Lt2 => "lt2"
    Accent1 => "accent1"
    Accent2 => "accent2"
    Accent3 => "accent3"
    Accent4 => "accent4"
    Accent5 => "accent5"
    Accent6 => "accent6"
    Hlink => "hlink"
    FolHlink => "folHlink"
    PhClr => "phClr"
  }
}

///|
/// Parse an OOXML `val` attribute string. Raises `UnitsError::UnknownSchemeColor`
/// for any other input.
pub fn ThemeColor::from_xml(s : String) -> ThemeColor raise UnitsError {
  match s {
    "bg1" => Bg1
    "bg2" => Bg2
    "tx1" => Tx1
    "tx2" => Tx2
    "dk1" => Dk1
    "dk2" => Dk2
    "lt1" => Lt1
    "lt2" => Lt2
    "accent1" => Accent1
    "accent2" => Accent2
    "accent3" => Accent3
    "accent4" => Accent4
    "accent5" => Accent5
    "accent6" => Accent6
    "hlink" => Hlink
    "folHlink" => FolHlink
    "phClr" => PhClr
    _ => raise UnknownSchemeColor(s)
  }
}

///|
pub impl Show for ThemeColor with output(self, logger) {
  logger.write_string("ThemeColor::")
  logger.write_string(self.to_xml())
}

///|
/// A color transform applied to a `SchemeColor` (or any color reference).
///
/// Modeled after the most common children of OOXML `CT_SchemeColor`. The
/// transforms are applied in the order they appear in the `transforms` array.
pub(all) enum ColorTransform {
  /// Lighten toward white. `Percentage(50.0)` blends 50% with white.
  Tint(Percentage)
  /// Darken toward black. `Percentage(50.0)` blends 50% with black.
  Shade(Percentage)
  /// Modulate (multiply) the saturation. `Percentage(75.0)` scales sat to 75%.
  SatMod(Percentage)
  /// Modulate (multiply) the luminance.
  LumMod(Percentage)
  /// Set the opacity. `Percentage(50.0)` is half-transparent.
  Alpha(Percentage)
} derive(Eq, Debug)

///|
pub impl Show for ColorTransform with output(self, logger) {
  match self {
    Tint(p) => logger.write_string("Tint(\{p.value()}%)")
    Shade(p) => logger.write_string("Shade(\{p.value()}%)")
    SatMod(p) => logger.write_string("SatMod(\{p.value()}%)")
    LumMod(p) => logger.write_string("LumMod(\{p.value()}%)")
    Alpha(p) => logger.write_string("Alpha(\{p.value()}%)")
  }
}

///|
/// A reference to a theme color with an ordered list of transforms.
pub(all) struct SchemeColor {
  base : ThemeColor
  transforms : Array[ColorTransform]
} derive(Debug)

///|
/// Construct a scheme color reference with no transforms.
pub fn SchemeColor::new(base : ThemeColor) -> SchemeColor {
  { base, transforms: [] }
}

///|
/// Return a new `SchemeColor` with `t` appended to the transform list.
/// Builders are immutable: the original value is unchanged.
pub fn SchemeColor::with_transform(
  self : SchemeColor,
  t : ColorTransform,
) -> SchemeColor {
  let combined = Array::new(capacity=self.transforms.length() + 1)
  for x in self.transforms {
    combined.push(x)
  }
  combined.push(t)
  { base: self.base, transforms: combined }
}

///|
pub impl Show for SchemeColor with output(self, logger) {
  logger.write_string("SchemeColor(")
  logger.write_object(self.base)
  if self.transforms.length() > 0 {
    logger.write_string(", [")
    for i, t in self.transforms {
      if i > 0 {
        logger.write_string(", ")
      }
      logger.write_object(t)
    }
    logger.write_string("]")
  }
  logger.write_string(")")
}
