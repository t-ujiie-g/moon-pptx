// Builders for the `<a:effectLst>` records parsed in `effect.mbt`.
//
// `PictureUncropped::with_effects` takes an `EffectList`, and until these
// existed a record literal across eight fields was the only way to produce
// one — which is why nothing in the tree passed that argument.
//
// Required attributes are constructor parameters; optional ones are
// `with_*` builders, immutable per ADR-003. The `dist` / `dir` pair on the
// shadow family is labelled because `blur_rad` and `dist` are both `Emu`
// and would otherwise swap silently.

///|
/// `<a:blur rad="…" grow="…"/>`. `grow` — whether the blur may extend past
/// the shape bounds — is left unset unless given; ECMA-376 defaults it to
/// true.
pub fn Blur::new(rad : @units.Emu, grow? : Bool) -> Blur {
  { rad, grow, }
}

///|
/// `<a:glow rad="…">` with its required colour.
pub fn Glow::new(rad : @units.Emu, color : Color) -> Glow {
  { rad, color, }
}

///|
/// `<a:softEdge rad="…"/>` — fades the shape edge inward.
pub fn SoftEdge::new(rad : @units.Emu) -> SoftEdge {
  { rad, }
}

///|
/// `<a:innerShdw>` — every attribute it carries is required by the schema.
pub fn InnerShadow::new(
  blur_rad~ : @units.Emu,
  dist~ : @units.Emu,
  dir~ : @units.Angle,
  color~ : Color,
) -> InnerShadow {
  { blur_rad, dist, dir, color, }
}

///|
/// `<a:prstShdw prst="…">` — `preset` is one of the 20 names in
/// `ST_PresetShadowVal` (`"shdw1"` … `"shdw20"`), kept as a `String` so an
/// unknown one still round-trips.
pub fn PresetShadow::new(
  preset : String,
  dist~ : @units.Emu,
  dir~ : @units.Angle,
  color~ : Color,
) -> PresetShadow {
  { preset, dist, dir, color, }
}

///|
/// `<a:outerShdw>` with only its required attributes. The optional scale,
/// skew, alignment and `rotWithShape` ride on the `with_*` builders.
pub fn OuterShadow::new(
  blur_rad~ : @units.Emu,
  dist~ : @units.Emu,
  dir~ : @units.Angle,
  color~ : Color,
) -> OuterShadow {
  {
    blur_rad,
    dist,
    dir,
    sx: None,
    sy: None,
    kx: None,
    ky: None,
    alignment: None,
    rotate_with_shape: None,
    color,
  }
}

///|
/// Horizontal / vertical scaling of the shadow (`sx` / `sy`).
pub fn OuterShadow::with_scale(
  self : OuterShadow,
  sx~ : @units.Percentage,
  sy~ : @units.Percentage,
) -> OuterShadow {
  { ..self, sx: Some(sx), sy: Some(sy), }
}

///|
/// Horizontal / vertical skew of the shadow (`kx` / `ky`).
pub fn OuterShadow::with_skew(
  self : OuterShadow,
  kx~ : @units.Angle,
  ky~ : @units.Angle,
) -> OuterShadow {
  { ..self, kx: Some(kx), ky: Some(ky), }
}

///|
/// Which point of the bounding rect the shadow scales and skews about
/// (`algn`).
pub fn OuterShadow::with_alignment(
  self : OuterShadow,
  alignment : RectAlignment,
) -> OuterShadow {
  { ..self, alignment: Some(alignment), }
}

///|
/// Whether the shadow rotates with the shape (`rotWithShape`).
pub fn OuterShadow::with_rotate_with_shape(
  self : OuterShadow,
  rotate : Bool,
) -> OuterShadow {
  { ..self, rotate_with_shape: Some(rotate), }
}

///|
/// `<a:reflection/>` with nothing set — every attribute is optional, so
/// this is a valid reflection on its own and the `with_*` builders add
/// whatever the effect needs.
pub fn Reflection::default() -> Reflection {
  {
    blur_rad: None,
    st_a: None,
    st_pos: None,
    end_a: None,
    end_pos: None,
    dist: None,
    dir: None,
    fade_dir: None,
    sx: None,
    sy: None,
    kx: None,
    ky: None,
    alignment: None,
    rotate_with_shape: None,
  }
}

///|
/// Blur radius of the reflection (`blurRad`).
pub fn Reflection::with_blur_rad(
  self : Reflection,
  rad : @units.Emu,
) -> Reflection {
  { ..self, blur_rad: Some(rad), }
}

///|
/// Start and end alpha of the reflection's fade (`stA` / `endA`).
pub fn Reflection::with_alpha(
  self : Reflection,
  start~ : @units.Percentage,
  end~ : @units.Percentage,
) -> Reflection {
  { ..self, st_a: Some(start), end_a: Some(end), }
}

///|
/// Where along the reflection the start and end alpha apply (`stPos` /
/// `endPos`).
pub fn Reflection::with_positions(
  self : Reflection,
  start~ : @units.Percentage,
  end~ : @units.Percentage,
) -> Reflection {
  { ..self, st_pos: Some(start), end_pos: Some(end), }
}

///|
/// How far the reflection sits from the shape (`dist`).
pub fn Reflection::with_distance(
  self : Reflection,
  dist : @units.Emu,
) -> Reflection {
  { ..self, dist: Some(dist), }
}

///|
/// Direction the reflection is offset in (`dir`).
pub fn Reflection::with_direction(
  self : Reflection,
  dir : @units.Angle,
) -> Reflection {
  { ..self, dir: Some(dir), }
}

///|
/// Direction the reflection fades along (`fadeDir`), which is independent
/// of the offset direction.
pub fn Reflection::with_fade_direction(
  self : Reflection,
  dir : @units.Angle,
) -> Reflection {
  { ..self, fade_dir: Some(dir), }
}

///|
/// Horizontal / vertical scaling of the reflection (`sx` / `sy`).
pub fn Reflection::with_scale(
  self : Reflection,
  sx~ : @units.Percentage,
  sy~ : @units.Percentage,
) -> Reflection {
  { ..self, sx: Some(sx), sy: Some(sy), }
}

///|
/// Horizontal / vertical skew of the reflection (`kx` / `ky`).
pub fn Reflection::with_skew(
  self : Reflection,
  kx~ : @units.Angle,
  ky~ : @units.Angle,
) -> Reflection {
  { ..self, kx: Some(kx), ky: Some(ky), }
}

///|
/// Which point of the bounding rect the reflection scales and skews about
/// (`algn`).
pub fn Reflection::with_alignment(
  self : Reflection,
  alignment : RectAlignment,
) -> Reflection {
  { ..self, alignment: Some(alignment), }
}

///|
/// Whether the reflection rotates with the shape (`rotWithShape`).
pub fn Reflection::with_rotate_with_shape(
  self : Reflection,
  rotate : Bool,
) -> Reflection {
  { ..self, rotate_with_shape: Some(rotate), }
}

///|
/// `<a:effectLst/>` with no effects. Add them with the `with_*` builders;
/// the writer emits whatever is set in the source order the schema fixes.
pub fn EffectList::empty() -> EffectList {
  {
    blur: None,
    glow: None,
    inner_shadow: None,
    outer_shadow: None,
    preset_shadow: None,
    reflection: None,
    soft_edge: None,
    extension: [],
  }
}

///|
pub fn EffectList::with_blur(self : EffectList, blur : Blur) -> EffectList {
  { ..self, blur: Some(blur), }
}

///|
pub fn EffectList::with_glow(self : EffectList, glow : Glow) -> EffectList {
  { ..self, glow: Some(glow), }
}

///|
pub fn EffectList::with_inner_shadow(
  self : EffectList,
  shadow : InnerShadow,
) -> EffectList {
  { ..self, inner_shadow: Some(shadow), }
}

///|
pub fn EffectList::with_outer_shadow(
  self : EffectList,
  shadow : OuterShadow,
) -> EffectList {
  { ..self, outer_shadow: Some(shadow), }
}

///|
pub fn EffectList::with_preset_shadow(
  self : EffectList,
  shadow : PresetShadow,
) -> EffectList {
  { ..self, preset_shadow: Some(shadow), }
}

///|
pub fn EffectList::with_reflection(
  self : EffectList,
  reflection : Reflection,
) -> EffectList {
  { ..self, reflection: Some(reflection), }
}

///|
pub fn EffectList::with_soft_edge(
  self : EffectList,
  edge : SoftEdge,
) -> EffectList {
  { ..self, soft_edge: Some(edge), }
}
