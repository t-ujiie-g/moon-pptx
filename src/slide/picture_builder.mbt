// Typed picture builder state machine (roadmap v0.4 D4).
//
// A compile-time-enforced construction pipeline for `Picture`:
//
//   Picture::builder(...)   -> PictureUncropped
//     .with_crop(...)       -> PictureCropped   (croppable at most once)
//     .with_effects(...)    -> PictureFinal     (effects at most once, after any crop)
//     .build()              -> Picture          (the existing flat type)
//
// Each state exposes only the operations valid from it, so cropping
// twice — or applying effects and *then* cropping — is a type error,
// not a runtime surprise. `build()` is available at every stage (crop
// and effects are both optional). This is the v0.4 "MoonBit
// differentiator" applied to the image pipeline; it complements the
// flat `Picture::of_image` / `with_crop` builders, which stay as the
// unconstrained path.
//
// The builder state types are opaque (`pub struct` with package-private
// fields): callers move through them only via the methods below.
//
// Deviation from the roadmap sketch: the entry point is a new
// `Picture::builder(...)` rather than re-typing `Picture::of_image`,
// whose `-> Picture` return type is load-bearing for existing callers
// and the presentation-level `add_picture_mut` pipeline.

///|
/// Stage 1 — a freshly-created picture with no crop applied yet.
/// Offers `with_crop`, `with_effects` (skipping the crop), and `build`.
pub struct PictureUncropped {
  pic : Picture
}

///|
/// Stage 2 — the crop has been chosen. `with_crop` is no longer
/// available (cropping twice is a compile error); offers `with_effects`
/// and `build`.
pub struct PictureCropped {
  pic : Picture
}

///|
/// Stage 3 — effects have been applied. Only `build` remains.
pub struct PictureFinal {
  pic : Picture
}

///|
/// Start the typed picture pipeline. Same parameters as
/// `Picture::of_image` (a stretched fit inside a `prst="rect"`
/// boundary); `embed_id` is the `r:embed` of the image media part.
pub fn Picture::builder(
  id : Int,
  name : String,
  embed_id : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> PictureUncropped {
  { pic: Picture::of_image(id, name, embed_id, x, y, cx, cy) }
}

///|
/// Crop the picture by `(left, top, right, bottom)` percentages off each
/// edge, then advance to the cropped stage. Mirrors `Picture::with_crop`;
/// it can only be called once (the result has no `with_crop`).
pub fn PictureUncropped::with_crop(
  self : PictureUncropped,
  left? : @units.Percentage = @units.Percentage(0.0),
  top? : @units.Percentage = @units.Percentage(0.0),
  right? : @units.Percentage = @units.Percentage(0.0),
  bottom? : @units.Percentage = @units.Percentage(0.0),
) -> PictureCropped {
  { pic: self.pic.with_crop(left~, top~, right~, bottom~) }
}

///|
/// Apply an outline (`<a:ln>`) and/or an effect list (`<a:effectLst>`),
/// then advance to the final stage. Either argument may be omitted to
/// leave that property unset.
pub fn PictureUncropped::with_effects(
  self : PictureUncropped,
  outline? : @oxml.Stroke,
  effects? : @oxml.EffectList,
) -> PictureFinal {
  { pic: apply_picture_effects(self.pic, outline, effects) }
}

///|
/// Build the flat `Picture` (skipping crop and effects).
pub fn PictureUncropped::build(self : PictureUncropped) -> Picture {
  self.pic
}

///|
/// Apply an outline and/or an effect list, then advance to the final
/// stage.
pub fn PictureCropped::with_effects(
  self : PictureCropped,
  outline? : @oxml.Stroke,
  effects? : @oxml.EffectList,
) -> PictureFinal {
  { pic: apply_picture_effects(self.pic, outline, effects) }
}

///|
/// Build the flat `Picture` (with the crop, without effects).
pub fn PictureCropped::build(self : PictureCropped) -> Picture {
  self.pic
}

///|
/// Build the flat `Picture` (with crop + effects as applied).
pub fn PictureFinal::build(self : PictureFinal) -> Picture {
  self.pic
}

///|
/// Set the optional outline / effect-list on a picture, leaving a field
/// untouched when its argument is `None`.
fn apply_picture_effects(
  pic : Picture,
  outline : @oxml.Stroke?,
  effects : @oxml.EffectList?,
) -> Picture {
  let with_outline = match outline {
    Some(s) => { ..pic, stroke: Some(s) }
    None => pic
  }
  match effects {
    Some(e) => { ..with_outline, effects: Some(e) }
    None => with_outline
  }
}
