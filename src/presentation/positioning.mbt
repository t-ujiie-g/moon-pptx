// Percentage / relative positioning helpers (v0.2 C2).
//
// PptxGenJS lets users say `x: "5%"` meaning "5% of slide width";
// the equivalent in moon-pptx is `prs.pct_w(5.0)`. Returning an
// `@units.Emu` plays naturally with the rest of the typed-units
// API so the user never has to compute EMU arithmetic by hand.
//
// We expose width / height resolvers separately rather than a
// single `pct_of(side, n)` because picking the wrong axis is the
// kind of bug type-safety should catch — if a future revision uses
// distinct `EmuW` / `EmuH` newtypes these will keep working
// unchanged.

///|
/// Resolve a percent value to EMU along the slide's horizontal
/// axis. `pct_w(5.0)` returns 5 % of the deck's current slide
/// width.
///
/// Falls back to ECMA-376's `screen4x3` default (9_144_000 EMU)
/// when the package has no `<p:sldSz>` — only happens on malformed
/// input.
pub fn Presentation::pct_w(self : Presentation, percent : Double) -> @units.Emu {
  let cx = self.slide_size_or_default().cx.value()
  @units.Emu((cx.to_double() * percent / 100.0).to_int64())
}

///|
/// Resolve a percent value to EMU along the slide's vertical axis.
/// `pct_h(50.0)` returns half the slide height.
pub fn Presentation::pct_h(self : Presentation, percent : Double) -> @units.Emu {
  let cy = self.slide_size_or_default().cy.value()
  @units.Emu((cy.to_double() * percent / 100.0).to_int64())
}

///|
/// Slide width in EMU. Same fallback as `pct_w`.
pub fn Presentation::slide_w(self : Presentation) -> @units.Emu {
  self.slide_size_or_default().cx
}

///|
/// Slide height in EMU. Same fallback as `pct_h`.
pub fn Presentation::slide_h(self : Presentation) -> @units.Emu {
  self.slide_size_or_default().cy
}

///|
/// Internal: fetch `<p:sldSz>` from `presentation.xml`, or fall
/// back to `screen4x3` defaults. Never raises — degrades to defaults
/// on parse failure so positioning helpers don't bring their own
/// failure paths into builder code.
fn Presentation::slide_size_or_default(self : Presentation) -> SlideSize {
  let default : SlideSize = {
    cx: @units.Emu(9_144_000L),
    cy: @units.Emu(6_858_000L),
    size_type: "screen4x3",
  }
  let parsed = try? self.presentation_part()
  match parsed {
    Ok(Some(p)) =>
      match p.sld_sz {
        Some(s) => s
        None => default
      }
    _ => default
  }
}
