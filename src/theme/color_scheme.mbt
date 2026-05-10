// Theme color scheme — the 12 named slots that drive every theme-color
// reference in the deck (ECMA-376 §20.1.6.2).
//
// Each slot wraps a single color element. In real themes the wrapped element
// is almost always `a:srgbClr` (literal RGB) or `a:sysClr` (host system
// color with a `lastClr` fallback). The other DrawingML color elements
// (`a:schemeClr`, `a:hslClr`, `a:scrgbClr`, `a:prstClr`) are valid here per
// the schema but virtually never appear inside `clrScheme`; we'll add them
// to `ColorChoice` if a real-world theme requires it.

///|
/// One color choice within a theme color slot.
pub(all) enum ColorChoice {
  /// `<a:srgbClr val="FF0000"/>` — literal RGB.
  Srgb(@units.RgbColor)
  /// `<a:sysClr val="windowText" lastClr="000000"/>` — host system color
  /// with a fallback RGB used when the system value can't be resolved.
  Sys(SysColor)
} derive(Eq, Debug)

///|
pub impl Show for ColorChoice with output(self, logger) {
  match self {
    Srgb(c) => {
      logger.write_string("Srgb(")
      logger.write_object(c)
      logger.write_string(")")
    }
    Sys(c) => {
      logger.write_string("Sys(")
      logger.write_object(c)
      logger.write_string(")")
    }
  }
}

///|
/// `<a:sysClr val="…" lastClr="…"/>` — a host system color with a fallback.
pub(all) struct SysColor {
  /// The system color name, e.g. `"windowText"`, `"window"`, `"3dShadow"`.
  /// Per ECMA-376 §20.1.10.58 (`ST_SystemColorVal`).
  val : String
  /// The literal RGB to fall back to when the host can't resolve `val`.
  /// `None` is permitted by the schema but real PPTX always supplies it.
  last_clr : @units.RgbColor?
} derive(Eq, Debug)

///|
pub impl Show for SysColor with output(self, logger) {
  logger.write_string("SysColor(")
  logger.write_object(self.val)
  match self.last_clr {
    Some(c) => {
      logger.write_string(", last=")
      logger.write_object(c)
    }
    None => ()
  }
  logger.write_string(")")
}

///|
/// A theme color scheme — twelve named slots in fixed order per ECMA-376.
///
/// `dk1` / `lt1` / `dk2` / `lt2` are the master-level definitions; the
/// slide-level mapping (`bg1` / `tx1` / `bg2` / `tx2`) refers to these.
/// `accent1`..`accent6` are the brand colours, `hlink` and `folHlink` the
/// hyperlink and followed-hyperlink colours.
pub(all) struct ColorScheme {
  name : String
  dk1 : ColorChoice
  lt1 : ColorChoice
  dk2 : ColorChoice
  lt2 : ColorChoice
  accent1 : ColorChoice
  accent2 : ColorChoice
  accent3 : ColorChoice
  accent4 : ColorChoice
  accent5 : ColorChoice
  accent6 : ColorChoice
  hlink : ColorChoice
  fol_hlink : ColorChoice
} derive(Eq, Debug)
