// Animation DSL — typed `<p:timing>` (roadmap v0.5 D2).
//
// `<p:timing>` (CT_SlideTiming, ECMA-376 §19.3.1.48) is the slide's animation
// tree. It is one of the deepest, most boilerplate-heavy parts of the format: a
// fixed "main sequence" scaffold (tmRoot → seq → mainSeq) wraps one node per
// click group, and each visible effect adds a leaf of behaviour elements
// (`<p:set>` / `<p:animEffect>` / …). PowerPoint regenerates that scaffold
// identically for every deck, so D2 models the *high-level* intent — an ordered
// list of effects, each targeting a shape with a start mode — and the writer
// (`animation_writer.mbt`) synthesises the full canonical tree.
//
// Scope (slice 1, documented like the A6/A7/C4/D3 deviations):
//   * **Entrance + Exit** effects driven by a DrawingML `<p:animEffect>` filter
//     (or a bare `<p:set>` for Appear/Disappear). The same filter family powers
//     both; an entrance plays it `in` and reveals the shape, an exit plays it
//     `out` and hides it.
//   * Start modes: on click / with previous / after previous, grouped into the
//     standard click-driven main sequence.
//   * **Build-only** (like A6 media): a typed `Slide.timing` is emitted by the
//     writer; on parse, an existing `<p:timing>` still round-trips losslessly
//     through `Slide.extension` (ADR-004) and `timing` stays `None`. So a built
//     timeline re-serialises stably rather than round-tripping to an equal
//     model — the established build-only deviation.
//
// Deferred follow-ups (the model extends additively): **Emphasis** effects
// (`<p:animClr>` / `<p:animScale>` / `<p:animRot>`), **motion paths** (reusing
// `CustomGeometry::PathCommand`), Fly-In-style positional `<p:anim>` effects,
// per-paragraph text builds (`<p:bldLst>`), and precise per-direction
// `presetSubtype` UI hints (slice 1 emits `presetSubtype="0"`, which PowerPoint
// renders from the filter regardless).

///|
/// Direction for a directional effect — the argument of a `filter` like
/// `wipe(up)`. `to_filter` yields the lower-case filter word.
pub(all) enum AnimDirection {
  Up
  Down
  Left
  Right
} derive(Eq, Debug)

///|
/// The `filter` argument word for this direction (`wipe(<word>)`).
pub fn AnimDirection::to_filter(self : AnimDirection) -> String {
  match self {
    Up => "up"
    Down => "down"
    Left => "left"
    Right => "right"
  }
}

///|
/// Orientation for blinds / random-bars effects — the `filter` argument word
/// (`blinds(horizontal)`).
pub(all) enum AnimOrientation {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
pub fn AnimOrientation::to_filter(self : AnimOrientation) -> String {
  match self {
    Horizontal => "horizontal"
    Vertical => "vertical"
  }
}

///|
/// A visual transition effect usable as either an entrance or an exit. The same
/// DrawingML `<p:animEffect filter="…">` drives both directions, so one enum
/// serves both `Entrance` and `Exit`. `Appear` is the degenerate instant case
/// (a bare `<p:set>` toggling visibility, no `<p:animEffect>`).
///
/// `preset_id` / `filter` are exhaustive over this enum, so adding a new effect
/// without classifying it is a compile error.
pub(all) enum VisualEffect {
  /// Instant show (entrance) / hide (exit) — no `<p:animEffect>`.
  Appear
  /// Fade in / out (`filter="fade"`).
  Fade
  /// Directional wipe (`filter="wipe(up|down|left|right)"`).
  Wipe(AnimDirection)
  /// Venetian blinds (`filter="blinds(horizontal|vertical)"`).
  Blinds(AnimOrientation)
  /// Random bars (`filter="randombar(horizontal|vertical)"`).
  RandomBars(AnimOrientation)
  /// Dissolve (`filter="dissolve"`).
  Dissolve
  /// Wedge / clock sweep (`filter="wedge"`).
  Wedge
  /// Wheel with N spokes (`filter="wheel(N)"`).
  Wheel(Int)
} derive(Eq, Debug)

///|
/// The PowerPoint `presetID` for this effect (the entrance-class numbering;
/// reused for the exit class, where it is a cosmetic UI hint). Exhaustive.
pub fn VisualEffect::preset_id(self : VisualEffect) -> Int {
  match self {
    Appear => 1
    Fade => 10
    Wipe(_) => 22
    Blinds(_) => 3
    RandomBars(_) => 14
    Dissolve => 9
    Wedge => 20
    Wheel(_) => 21
  }
}

///|
/// The `<p:animEffect filter="…">` string, or `None` for `Appear` (which is a
/// bare `<p:set>` with no `<p:animEffect>`). Exhaustive over `VisualEffect`.
pub fn VisualEffect::filter(self : VisualEffect) -> String? {
  match self {
    Appear => None
    Fade => Some("fade")
    Wipe(d) => Some("wipe(" + d.to_filter() + ")")
    Blinds(o) => Some("blinds(" + o.to_filter() + ")")
    RandomBars(o) => Some("randombar(" + o.to_filter() + ")")
    Dissolve => Some("dissolve")
    Wedge => Some("wedge")
    Wheel(spokes) => Some("wheel(" + spokes.to_string() + ")")
  }
}

///|
/// An animation applied to a shape: either an `Entrance` (the shape appears) or
/// an `Exit` (the shape leaves). Both wrap the shared `VisualEffect`; the
/// writer sets `presetClass="entr"`/`"exit"`, plays the filter `in`/`out`, and
/// reveals/hides the shape with a `<p:set>` on `style.visibility`.
///
/// (Emphasis + motion-path effects are a documented follow-up; this enum
/// extends to them additively.)
pub(all) enum AnimEffect {
  Entrance(VisualEffect)
  Exit(VisualEffect)
} derive(Eq, Debug)

///|
/// When an effect starts, relative to the timeline.
pub(all) enum AnimStart {
  /// Waits for a mouse click — starts a new click group in the main sequence.
  OnClick
  /// Starts together with the previous effect (joins the current group).
  WithPrevious
  /// Starts when the previous effect ends — a new auto-advancing group.
  AfterPrevious
} derive(Eq, Debug)

///|
/// One step of a slide's animation timeline: an `effect` applied to the shape
/// with id `target_shape_id` (see `Shape::id`), starting per `start`, lasting
/// `duration_ms` milliseconds.
pub(all) struct AnimStep {
  effect : AnimEffect
  target_shape_id : Int
  start : AnimStart
  duration_ms : Int
} derive(Eq, Debug)

///|
/// A slide's animation timeline — the typed form of `<p:timing>`. An ordered
/// list of `AnimStep`s; the writer groups them into the canonical click-driven
/// main sequence. Build it fluently:
///
/// ```
/// let tl = Timeline::new()
///   .on_click(Entrance(Fade), title_id)
///   .after_previous(Entrance(Wipe(Up)), body_id)
///   .with_previous(Entrance(Appear), logo_id)
/// let slide = slide.with_animations(tl)
/// ```
pub(all) struct Timeline {
  steps : Array[AnimStep]
} derive(Eq, Debug)

///|
/// The default effect duration PowerPoint uses for most animations (0.5 s).
pub let anim_default_duration_ms : Int = 500

///|
/// An empty timeline. Add steps with `on_click` / `with_previous` /
/// `after_previous`.
pub fn Timeline::new() -> Timeline {
  { steps: [] }
}

///|
/// Append a step. Immutable (ADR-003) — returns a new `Timeline`.
fn Timeline::add(
  self : Timeline,
  effect : AnimEffect,
  target_shape_id : Int,
  start : AnimStart,
  duration_ms : Int,
) -> Timeline {
  let steps = self.steps.copy()
  steps.push({ effect, target_shape_id, start, duration_ms })
  { steps, }
}

///|
/// Add an effect that plays on the next mouse click (a new click group).
pub fn Timeline::on_click(
  self : Timeline,
  effect : AnimEffect,
  target_shape_id : Int,
  duration_ms? : Int = anim_default_duration_ms,
) -> Timeline {
  self.add(effect, target_shape_id, OnClick, duration_ms)
}

///|
/// Add an effect that plays together with the previous one. If it is the first
/// step it behaves like `on_click`.
pub fn Timeline::with_previous(
  self : Timeline,
  effect : AnimEffect,
  target_shape_id : Int,
  duration_ms? : Int = anim_default_duration_ms,
) -> Timeline {
  self.add(effect, target_shape_id, WithPrevious, duration_ms)
}

///|
/// Add an effect that plays automatically after the previous one finishes (a
/// new auto-advancing group).
pub fn Timeline::after_previous(
  self : Timeline,
  effect : AnimEffect,
  target_shape_id : Int,
  duration_ms? : Int = anim_default_duration_ms,
) -> Timeline {
  self.add(effect, target_shape_id, AfterPrevious, duration_ms)
}

// --- Slide builders (immutable, ADR-003) ---

///|
/// Return a new `Slide` with the given animation timeline. Replaces any
/// existing one, and drops a captured `<p:timing>` from `extension` (a parsed
/// deck round-trips its timing there) so the typed timeline is the single
/// source — the writer never double-emits `<p:timing>`.
pub fn Slide::with_animations(self : Slide, timeline : Timeline) -> Slide {
  { ..self, timing: Some(timeline), extension: without_timing(self.extension) }
}

///|
/// Return a new `Slide` with no animation timeline. Clears both the typed field
/// and any captured `<p:timing>` in `extension`.
pub fn Slide::without_animations(self : Slide) -> Slide {
  { ..self, timing: None, extension: without_timing(self.extension) }
}

///|
/// Drop any `<p:timing>` element from a captured-extension array.
fn without_timing(extension : Array[@xml.XmlElement]) -> Array[@xml.XmlElement] {
  extension.filter(fn(el) {
    !(el.name.uri == @oxml.presentation_ns && el.name.local_name == "timing")
  })
}
