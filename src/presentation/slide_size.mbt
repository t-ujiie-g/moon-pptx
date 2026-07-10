// Slide-size selector.
//
// `Presentation::set_slide_size_mut(SlideSizeKind)` updates the
// deck's `<p:sldSz>` attribute set in one call. `SlideSizeKind`
// enumerates the most commonly-used `ST_SlideSizeType` presets plus
// a `Custom(cx, cy)` escape hatch for sizes the spec enum doesn't
// cover (or for callers that want explicit EMU values).
//
// We don't enumerate every single ST_SlideSizeType value — the
// long-tail ones (`hagaki`, `B4JIS`, `B5JIS`, `overhead`, etc.) can
// always be expressed via `Custom`. Adding more presets later is
// purely additive.

///|
/// Common slide-size presets. The spec's `ST_SlideSizeType` has
/// 17 values; we surface the practical subset plus `Custom`.
pub(all) enum SlideSizeKind {
  /// 10" × 7.5" — classic 4:3 aspect ratio. `Presentation::new()`'s
  /// default. ST_SlideSizeType `screen4x3`.
  ScreenFourByThree
  /// 10" × 5.625" — 16:9 narrow widescreen. ST_SlideSizeType
  /// `screen16x9`.
  ScreenSixteenByNine
  /// 10" × 6.25" — 16:10 widescreen. ST_SlideSizeType `screen16x10`.
  ScreenSixteenByTen
  /// 13.333" × 7.5" — modern PowerPoint default since 2013 ("Widescreen"
  /// in the Design tab). Stored as ST_SlideSizeType `custom` because
  /// the spec doesn't have a dedicated enum value for this ratio.
  Widescreen
  /// 10" × 7.5" — US Letter landscape. ST_SlideSizeType `letter`.
  Letter
  /// 11.69" × 8.27" — ISO A4 landscape. ST_SlideSizeType `A4`.
  A4
  /// 12.5" × 8.33" — 35 mm slide. ST_SlideSizeType `35mm`.
  ThirtyFiveMm
  /// 8" × 1" — banner. ST_SlideSizeType `banner`.
  Banner
  /// Arbitrary EMU dimensions (cx, cy). Stored with
  /// ST_SlideSizeType `custom`.
  Custom(@units.Emu, @units.Emu)
} derive(Eq, Debug)

///|
pub impl Show for SlideSizeKind with fn output(self, logger) {
  let (cx, cy) = self.dimensions()
  let cx_v = cx.value().to_string()
  let cy_v = cy.value().to_string()
  let label = match self {
    ScreenFourByThree => "ScreenFourByThree"
    ScreenSixteenByNine => "ScreenSixteenByNine"
    ScreenSixteenByTen => "ScreenSixteenByTen"
    Widescreen => "Widescreen"
    Letter => "Letter"
    A4 => "A4"
    ThirtyFiveMm => "ThirtyFiveMm"
    Banner => "Banner"
    Custom(_, _) => "Custom"
  }
  logger.write_string(label)
  logger.write_string("(")
  logger.write_string(cx_v)
  logger.write_string("x")
  logger.write_string(cy_v)
  logger.write_string(" EMU)")
}

///|
/// `(cx, cy)` dimensions in EMU for this preset.
pub fn SlideSizeKind::dimensions(
  self : SlideSizeKind,
) -> (@units.Emu, @units.Emu) {
  match self {
    ScreenFourByThree => (@units.Emu(9_144_000L), @units.Emu(6_858_000L))
    ScreenSixteenByNine => (@units.Emu(9_144_000L), @units.Emu(5_143_500L))
    ScreenSixteenByTen => (@units.Emu(9_144_000L), @units.Emu(5_715_000L))
    Widescreen => (@units.Emu(12_192_000L), @units.Emu(6_858_000L))
    Letter => (@units.Emu(9_144_000L), @units.Emu(6_858_000L))
    A4 => (@units.Emu(10_692_000L), @units.Emu(7_560_000L))
    ThirtyFiveMm => (@units.Emu(11_430_000L), @units.Emu(7_620_000L))
    Banner => (@units.Emu(7_315_200L), @units.Emu(914_400L))
    Custom(cx, cy) => (cx, cy)
  }
}

///|
/// The OOXML `type` attribute string for this preset
/// (ST_SlideSizeType value). Returns `""` for `Custom(_, _)` and
/// `Widescreen` — though the spec defines a `"custom"` value, real
/// PowerPoint omits the `type` attribute entirely for non-preset
/// dimensions, and `type="custom"` triggers PowerPoint Online's
/// repair banner.
pub fn SlideSizeKind::size_type(self : SlideSizeKind) -> String {
  match self {
    ScreenFourByThree => "screen4x3"
    ScreenSixteenByNine => "screen16x9"
    ScreenSixteenByTen => "screen16x10"
    Widescreen => ""
    Letter => "letter"
    A4 => "A4"
    ThirtyFiveMm => "35mm"
    Banner => "banner"
    Custom(_, _) => ""
  }
}

///|
/// Convert to a typed `SlideSize` value (cx, cy, size_type).
pub fn SlideSizeKind::to_slide_size(self : SlideSizeKind) -> SlideSize {
  let (cx, cy) = self.dimensions()
  { cx, cy, size_type: self.size_type() }
}

///|
/// Replace the deck's slide-size with `kind`. Mutates
/// `presentation.xml` in place. Raises `Malformed` if the package
/// has no parseable presentation.xml part.
///
/// Notes-coordinate-space (`<p:notesSz>`) is left untouched —
/// PowerPoint defaults it to 6_858_000 × 9_144_000 (portrait letter)
/// regardless of slide orientation.
pub fn Presentation::set_slide_size_mut(
  self : Presentation,
  kind : SlideSizeKind,
) -> Unit raise PptxError {
  let pres_name = match self.main_document_part_name() {
    Some(n) => n
    None =>
      raise Malformed(
        "set_slide_size_mut: package has no main-document relationship",
      )
  }
  let part = match self.presentation_part() {
    Some(p) => p
    None =>
      raise Malformed(
        "set_slide_size_mut: presentation.xml could not be parsed",
      )
  }
  let new_part : PresentationPart = {
    ..part,
    sld_sz: Some(kind.to_slide_size()),
  }
  let bytes = new_part.serialize()
  self.replace_part_bytes(pres_name, bytes, @oxml.ct_presentation)
}
