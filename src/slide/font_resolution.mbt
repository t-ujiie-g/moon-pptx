// Run → theme font resolution.
//
// A run rarely names the font it renders with. PowerPoint writes theme
// references — `<a:latin typeface="+mn-lt"/>` and friends — whenever text
// follows the theme, and it picks between a run's three typeface slots by the
// script of each character. So `RunProperties.latin` on a parsed deck is
// usually the string `"+mn-lt"`, and Japanese text in that same run may render
// in a font named nowhere on the run at all: the theme's
// `<a:font script="Jpan">` entry.
//
// These helpers close that gap. They cover the run → theme step; a run that
// inherits through a list style or a master placeholder needs those layers
// merged in first.

///|
/// The typefaces a run actually renders with, one per script slot.
pub(all) struct ResolvedFonts {
  latin : String
  east_asian : String
  complex_script : String
} derive(Eq, Debug)

///|
/// Resolve every typeface slot of `rp` against `scheme`.
///
/// A slot takes the run's own `<a:latin>` / `<a:ea>` / `<a:cs>` when it has
/// one, with a theme reference (`"+mn-ea"`) followed through to the font it
/// names; otherwise it takes the scheme's value directly. `major` selects the
/// heading collection (`<a:majorFont>`) over the body one.
///
/// An empty result means the theme leaves that slot empty — Office themes
/// ship `<a:ea typeface=""/>` — in which case PowerPoint falls back to the
/// per-script entries. Use `resolve_run_font_for_script` to get an answer for
/// specific text.
pub fn resolve_run_fonts(
  rp : RunProperties,
  scheme : @theme.FontScheme,
  major? : Bool = false,
) -> ResolvedFonts {
  let collection = if major { scheme.major_font } else { scheme.minor_font }
  fn slot(override_ : String?, theme_value : String) -> String {
    match override_ {
      Some(t) => scheme.resolve_typeface(t)
      None => theme_value
    }
  }

  {
    latin: slot(rp.latin, collection.latin),
    east_asian: slot(rp.east_asian, collection.ea),
    complex_script: slot(rp.complex_script, collection.cs),
  }
}

///|
/// The typeface this run renders `script` with — an ISO-15924 tag such as
/// `"Jpan"`, `"Hans"`, `"Hang"`, or `"Arab"`.
///
/// The run's override for that script's slot wins when it names a font;
/// otherwise the theme answers, preferring its `<a:font script="…">` entry
/// over the slot, because that is where Office themes actually put the CJK
/// faces.
pub fn resolve_run_font_for_script(
  rp : RunProperties,
  scheme : @theme.FontScheme,
  script : String,
  major? : Bool = false,
) -> String {
  let collection = if major { scheme.major_font } else { scheme.minor_font }
  let override_ = match @theme.ScriptSlot::of_script(script) {
    EastAsianSlot => rp.east_asian
    ComplexScriptSlot => rp.complex_script
    LatinSlot => rp.latin
  }
  match override_ {
    Some(t) => {
      let resolved = scheme.resolve_typeface(t)
      if resolved.is_empty() {
        collection.typeface_for_script(script)
      } else {
        resolved
      }
    }
    None => collection.typeface_for_script(script)
  }
}
