// Slide background — typed `<p:bg>` (roadmap v0.3 A7).
//
// `<p:bg>` (CT_Background) was previously captured into `Slide.extension`
// (ADR-004). A7 lifts it into a typed `Slide.background` field while keeping
// full round-trip fidelity: both the `<p:bgPr>` (explicit fill) and
// `<p:bgRef>` (theme style-matrix reference) forms are modelled, and any
// unmodelled `<p:bgPr>` children survive via `BackgroundProperties.extension`.

///|
/// A slide background, lifted from `<p:cSld><p:bg>` (CT_Background,
/// ECMA-376 §19.3.1.1). A slide with no `<p:bg>` inherits its background
/// from the layout / master, modelled as `Slide.background == None`.
pub(all) enum Background {
  /// `<p:bgPr>` — an explicit fill, optionally with effects.
  Properties(BackgroundProperties)
  /// `<p:bgRef>` — a reference into the theme's `bgFillStyleLst` (the `Int`
  /// `idx`, one-based) plus a colour that resolves the referenced style's
  /// `phClr` placeholder. This is the form `Presentation::new()` emits on
  /// its slide master.
  StyleReference(Int, @oxml.Color)
} derive(Eq, Debug)

///|
/// `<p:bgPr>` body (CT_BackgroundProperties, ECMA-376 §19.3.1.2).
pub(all) struct BackgroundProperties {
  /// The fill — `<a:solidFill>` / `<a:gradFill>` / `<a:blipFill>` /
  /// `<a:pattFill>` / `<a:noFill>`. The schema requires a fill, but it is
  /// `Option` (like `AutoShape.fill`) so the rare `<a:grpFill>` form, which
  /// `@oxml.Fill` doesn't model, round-trips via `extension` rather than
  /// being dropped.
  fill : @oxml.Fill?
  /// The `shadeToTitle` attribute (default `false`).
  shade_to_title : Bool
  /// `<a:effectLst>` if present.
  effects : @oxml.EffectList?
  /// Lossless preservation (ADR-004): `<a:effectDag>`, `<a:grpFill>`,
  /// `<a:extLst>`, and any other unmodelled `<p:bgPr>` children.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Build a `<p:bgPr>` background from a fill (no effects, `shadeToTitle`
/// unset) — the common case behind `Slide::with_background`.
pub fn BackgroundProperties::of_fill(fill : @oxml.Fill) -> BackgroundProperties {
  { fill: Some(fill), shade_to_title: false, effects: None, extension: [] }
}

// --- Slide builders (immutable, ADR-003) ---

///|
/// Return a new `Slide` with a solid-fill background of the given colour.
/// The most common case — e.g. a full-bleed brand colour behind a slide.
pub fn Slide::with_background(self : Slide, fill : @oxml.Fill) -> Slide {
  { ..self, background: Some(Properties(BackgroundProperties::of_fill(fill))) }
}

///|
/// Return a new `Slide` whose background references a theme background style
/// (`<p:bgRef>`): `idx` is the one-based index into the theme's
/// `bgFillStyleLst` and `color` resolves the style's `phClr` placeholder
/// (typically a scheme colour such as `bg1`).
pub fn Slide::with_background_ref(
  self : Slide,
  idx : Int,
  color : @oxml.Color,
) -> Slide {
  { ..self, background: Some(StyleReference(idx, color)) }
}

///|
/// Return a new `Slide` with no explicit background — it inherits the
/// layout / master background. Clears any previously set `background`.
pub fn Slide::without_background(self : Slide) -> Slide {
  { ..self, background: None }
}
