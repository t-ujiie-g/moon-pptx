// Color mapping (`p:clrMap`).
//
// Slides reference colors via the slide-level slot names `bg1`/`tx1`/`bg2`/
// `tx2` and `accent1..6`/`hlink`/`folHlink`. The slide-level → theme-slot
// resolution happens through the `<p:clrMap …/>` element on the slide
// master (and may be overridden on a slide layout via `<p:clrMapOvr>`).
//
// Schema (ECMA-376 §19.3.1.6, ST_ColorSchemeIndex):
//   <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2"
//             accent1="accent1" accent2="accent2" accent3="accent3"
//             accent4="accent4" accent5="accent5" accent6="accent6"
//             hlink="hlink" folHlink="folHlink"/>
//
// All twelve attributes are required. Each value names a theme color slot;
// we reuse `@units.ThemeColor` for that.

///|
/// Slide → theme color resolution table.
pub(all) struct ColorMapping {
  bg1 : @units.ThemeColor
  tx1 : @units.ThemeColor
  bg2 : @units.ThemeColor
  tx2 : @units.ThemeColor
  accent1 : @units.ThemeColor
  accent2 : @units.ThemeColor
  accent3 : @units.ThemeColor
  accent4 : @units.ThemeColor
  accent5 : @units.ThemeColor
  accent6 : @units.ThemeColor
  hlink : @units.ThemeColor
  fol_hlink : @units.ThemeColor
} derive(Eq, Debug)

///|
/// Look up the effective theme color for a slide-level slot reference.
/// Returns `None` only if the requested slot name isn't one of the twelve
/// known mapping keys.
pub fn ColorMapping::resolve(
  self : ColorMapping,
  slot : @units.ThemeColor,
) -> @units.ThemeColor? {
  match slot {
    Bg1 => Some(self.bg1)
    Tx1 => Some(self.tx1)
    Bg2 => Some(self.bg2)
    Tx2 => Some(self.tx2)
    Accent1 => Some(self.accent1)
    Accent2 => Some(self.accent2)
    Accent3 => Some(self.accent3)
    Accent4 => Some(self.accent4)
    Accent5 => Some(self.accent5)
    Accent6 => Some(self.accent6)
    Hlink => Some(self.hlink)
    FolHlink => Some(self.fol_hlink)
    // Master-level / placeholder slots are not slide-mapping keys.
    Dk1 | Dk2 | Lt1 | Lt2 | PhClr => None
  }
}
