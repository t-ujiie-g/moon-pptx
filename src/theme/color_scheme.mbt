// Theme color scheme — the 12 named slots that drive every theme-color
// reference in the deck (ECMA-376 §20.1.6.2).
//
// Each slot holds an `@oxml.Color`, the unified DrawingML colour
// representation. In real themes the wrapped element is almost always
// `<a:srgbClr>` or `<a:sysClr>`, but the model accepts every variant
// the spec allows (hsl / scheme / prst / scrgb) so unusual third-party
// themes round-trip without information loss.

///|
/// A theme color scheme — twelve named slots in fixed order per ECMA-376.
///
/// `dk1` / `lt1` / `dk2` / `lt2` are the master-level definitions; the
/// slide-level mapping (`bg1` / `tx1` / `bg2` / `tx2`) refers to these.
/// `accent1`..`accent6` are the brand colours, `hlink` and `folHlink` the
/// hyperlink and followed-hyperlink colours.
pub(all) struct ColorScheme {
  name : String
  dk1 : @oxml.Color
  lt1 : @oxml.Color
  dk2 : @oxml.Color
  lt2 : @oxml.Color
  accent1 : @oxml.Color
  accent2 : @oxml.Color
  accent3 : @oxml.Color
  accent4 : @oxml.Color
  accent5 : @oxml.Color
  accent6 : @oxml.Color
  hlink : @oxml.Color
  fol_hlink : @oxml.Color
} derive(Eq, Debug)
