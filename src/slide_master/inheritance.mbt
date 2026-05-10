// Inheritance resolution for slide-level effective values.
//
// At runtime, a slide inherits from a chain:
//   theme  ←  slide master  ←  slide layout  ←  slide
//
// The most-loaded inheritance question for any reader is: "given this slide,
// what concrete RGB does the named theme color slot resolve to?" That
// resolution walks two layers of indirection per ECMA-376:
//
//   1. The slide-level slot (`bg1`, `tx1`, `accent1`, …) is mapped through
//      the layout's `<p:clrMapOvr>` if it carries an explicit override,
//      otherwise through the master's `<p:clrMap>` (which the layout's
//      `<a:masterClrMapping/>` says to inherit).
//
//   2. The mapping result is itself a theme slot name (`dk1`, `lt1`,
//      `accent1`, …). Looking it up in the theme's `<a:clrScheme>` returns
//      the concrete `ColorChoice` (`Srgb` or `Sys`).
//
// This module exposes that two-step pipeline as small composable helpers so
// the eventual slide / shape / text parsers can resolve colours without
// re-implementing the spec's lookup rules.

///|
/// Choose the effective `ColorMapping` for a slide using the given layout
/// and master, applying the OOXML inheritance rule:
///   * `Override(...)` on the layout wins
///   * otherwise the master's `clrMap` is used (the `<a:masterClrMapping/>`
///     case, and also the spec default when `<p:clrMapOvr>` is absent)
pub fn effective_color_mapping(
  master : SlideMaster,
  layout : SlideLayout,
) -> ColorMapping {
  match layout.clr_map_override {
    Override(cm) => cm
    MasterMapping => master.color_mapping
  }
}

///|
/// Resolve a slide-level theme color slot to its concrete `ColorChoice` in
/// the theme. Performs both inheritance steps documented at the top of this
/// file:
///
///   1. Map slide-level slot → theme-level slot via the effective
///      `ColorMapping`.
///   2. Look up that theme-level slot in the supplied `ColorScheme`.
///
/// Returns `None` if the input slot is one that has no slide-level mapping
/// (the master-level slots `Dk1`/`Dk2`/`Lt1`/`Lt2` and the placeholder
/// `PhClr`). Callers that already hold a master-level slot should use
/// `lookup_theme_slot` directly.
pub fn resolve_slide_color(
  slot : @units.ThemeColor,
  master : SlideMaster,
  layout : SlideLayout,
  theme_scheme : @theme.ColorScheme,
) -> @theme.ColorChoice? {
  let mapping = effective_color_mapping(master, layout)
  match mapping.resolve(slot) {
    Some(theme_slot) => Some(lookup_theme_slot(theme_slot, theme_scheme))
    None => None
  }
}

///|
/// Look up a theme-level color slot in a `ColorScheme`. Always succeeds —
/// every variant of `@units.ThemeColor` has a defined slot in the scheme,
/// except `PhClr` (placeholder color) which is resolved at use site by
/// shape-style logic; we return the scheme's `accent1` as a safe fallback
/// so callers don't have to handle a separate error path. Real callers
/// should never pass `PhClr` here.
pub fn lookup_theme_slot(
  slot : @units.ThemeColor,
  scheme : @theme.ColorScheme,
) -> @theme.ColorChoice {
  match slot {
    Bg1 | Lt1 => scheme.lt1
    Bg2 | Lt2 => scheme.lt2
    Tx1 | Dk1 => scheme.dk1
    Tx2 | Dk2 => scheme.dk2
    Accent1 => scheme.accent1
    Accent2 => scheme.accent2
    Accent3 => scheme.accent3
    Accent4 => scheme.accent4
    Accent5 => scheme.accent5
    Accent6 => scheme.accent6
    Hlink => scheme.hlink
    FolHlink => scheme.fol_hlink
    PhClr => scheme.accent1 // placeholder fallback (see doc above)
  }
}
