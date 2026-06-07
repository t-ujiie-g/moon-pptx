// Slide transition — typed `<p:transition>` (roadmap v0.4 D3).
//
// `<p:transition>` (CT_SlideTransition, ECMA-376 §19.3.1.50) was previously
// captured into `Slide.extension` (ADR-004). D3 lifts it into a typed
// `Slide.transition` field, mirroring how A7 lifted `<p:bg>`. The effect is a
// choice of one transition-type child element (each carrying its own direction
// /orientation attribute); the wrapper carries the `spd` (speed), `advClick`
// (advance on mouse click), and `advTm` (auto-advance after N ms) attributes.
//
// Scope note: this models the base CT_SlideTransition only. PowerPoint 2010+
// also writes an `<mc:AlternateContent>` wrapper with `p14:` extended
// transitions (e.g. reveal, vortex, ferris) and a millisecond `p14:dur`
// duration; those round-trip losslessly through `Transition.extension` /
// `Slide.extension` but are not yet typed. Speed here is the spec's
// slow/med/fast (`spd`), not a millisecond duration.

///|
/// `ST_TransitionSpeed` (ECMA-376 §19.7.49) — the `spd` attribute. The schema
/// default is `Fast`.
pub(all) enum TransitionSpeed {
  Slow
  Medium
  Fast
} derive(Eq, Debug)

///|
/// Parse a `spd` value; anything unrecognised (including absent) falls back to
/// the schema default `Fast`.
pub fn TransitionSpeed::from_xml(s : String) -> TransitionSpeed {
  match s {
    "slow" => Slow
    "med" => Medium
    _ => Fast
  }
}

///|
pub fn TransitionSpeed::to_xml(self : TransitionSpeed) -> String {
  match self {
    Slow => "slow"
    Medium => "med"
    Fast => "fast"
  }
}

///|
/// `ST_TransitionSideDirectionType` (l/u/r/d) — the `dir` attribute on
/// `<p:push>` and `<p:wipe>`.
pub(all) enum TransitionSide {
  Left
  Up
  Right
  Down
} derive(Eq, Debug)

///|
pub fn TransitionSide::from_xml(s : String) -> TransitionSide {
  match s {
    "u" => Up
    "r" => Right
    "d" => Down
    _ => Left
  }
}

///|
pub fn TransitionSide::to_xml(self : TransitionSide) -> String {
  match self {
    Left => "l"
    Up => "u"
    Right => "r"
    Down => "d"
  }
}

///|
/// `ST_TransitionEightDirectionType` (l/u/r/d/lu/ru/ld/rd) — the `dir`
/// attribute on `<p:cover>` and `<p:pull>`.
pub(all) enum TransitionDirection {
  Left
  Up
  Right
  Down
  LeftUp
  RightUp
  LeftDown
  RightDown
} derive(Eq, Debug)

///|
pub fn TransitionDirection::from_xml(s : String) -> TransitionDirection {
  match s {
    "u" => Up
    "r" => Right
    "d" => Down
    "lu" => LeftUp
    "ru" => RightUp
    "ld" => LeftDown
    "rd" => RightDown
    _ => Left
  }
}

///|
pub fn TransitionDirection::to_xml(self : TransitionDirection) -> String {
  match self {
    Left => "l"
    Up => "u"
    Right => "r"
    Down => "d"
    LeftUp => "lu"
    RightUp => "ru"
    LeftDown => "ld"
    RightDown => "rd"
  }
}

///|
/// `ST_Direction` (horz/vert) — the `dir` attribute on `<p:blinds>` /
/// `<p:checker>` / `<p:comb>` / `<p:randomBar>` and the `orient` attribute on
/// `<p:split>`.
pub(all) enum TransitionOrientation {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
pub fn TransitionOrientation::from_xml(s : String) -> TransitionOrientation {
  match s {
    "vert" => Vertical
    _ => Horizontal
  }
}

///|
pub fn TransitionOrientation::to_xml(self : TransitionOrientation) -> String {
  match self {
    Horizontal => "horz"
    Vertical => "vert"
  }
}

///|
/// `ST_TransitionInOutDirectionType` (in/out) — the `dir` attribute on
/// `<p:split>` and `<p:zoom>`.
pub(all) enum TransitionInOut {
  In
  Out
} derive(Eq, Debug)

///|
pub fn TransitionInOut::from_xml(s : String) -> TransitionInOut {
  match s {
    "in" => In
    _ => Out
  }
}

///|
pub fn TransitionInOut::to_xml(self : TransitionInOut) -> String {
  match self {
    In => "in"
    Out => "out"
  }
}

///|
/// `ST_TransitionCornerDirectionType` (lu/ru/ld/rd) — the `dir` attribute on
/// `<p:strips>`.
pub(all) enum TransitionCorner {
  LeftUp
  RightUp
  LeftDown
  RightDown
} derive(Eq, Debug)

///|
pub fn TransitionCorner::from_xml(s : String) -> TransitionCorner {
  match s {
    "ru" => RightUp
    "ld" => LeftDown
    "rd" => RightDown
    _ => LeftUp
  }
}

///|
pub fn TransitionCorner::to_xml(self : TransitionCorner) -> String {
  match self {
    LeftUp => "lu"
    RightUp => "ru"
    LeftDown => "ld"
    RightDown => "rd"
  }
}

///|
/// Schema default for `<p:wheel spokes="…"/>` (CT_WheelTransition). The parser
/// falls back to it when the attribute is absent; the writer omits the
/// attribute when the value equals it. They must agree for round-trip
/// stability, so both reference this single constant.
let transition_default_spokes : Int = 4

///|
/// The transition effect — the single optional choice child of
/// `<p:transition>` (CT_SlideTransition). `NoEffect` is `<p:transition>` with
/// no choice child (a transition wrapper that only carries timing).
///
/// The `Bool` on `Fade` / `Cut` is the `thruBlk` (through-black) attribute; the
/// `Int` on `Wheel` is the `spokes` count (schema default 4). Direction- and
/// orientation-bearing variants carry the corresponding typed enum.
pub(all) enum TransitionKind {
  NoEffect
  Blinds(TransitionOrientation)
  Checker(TransitionOrientation)
  Circle
  Comb(TransitionOrientation)
  Cover(TransitionDirection)
  Cut(Bool) // thruBlk
  Diamond
  Dissolve
  Fade(Bool) // thruBlk
  Newsflash
  Plus
  Pull(TransitionDirection)
  Push(TransitionSide)
  Random
  RandomBar(TransitionOrientation)
  Split(TransitionOrientation, TransitionInOut) // orient, dir
  Strips(TransitionCorner)
  Wedge
  Wheel(Int) // spokes
  Wipe(TransitionSide)
  Zoom(TransitionInOut)
} derive(Eq, Debug)

///|
/// A slide transition, lifted from `<p:transition>` (CT_SlideTransition). A
/// slide with no transition is `Slide.transition == None` (the common case —
/// most slides have no entrance effect).
pub(all) struct Transition {
  /// The transition effect (the choice child element).
  kind : TransitionKind
  /// `spd` — the transition speed. Schema default `Fast`.
  speed : TransitionSpeed
  /// `advClick` — whether a mouse click advances the slide. Schema default
  /// `true`.
  advance_on_click : Bool
  /// `advTm` — auto-advance after this many milliseconds. `None` means the
  /// slide advances only on click (the attribute is absent).
  advance_after : Int?
  /// Lossless preservation (ADR-004): `<p:sndAc>` (transition sound),
  /// `<p:extLst>` (e.g. the `p14:` extended-transition definition), and any
  /// other unmodelled `<p:transition>` children.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Wrap a transition `kind` with the schema defaults: `Fast` speed, advance on
/// click, no timed auto-advance. The general constructor — pair it with
/// `with_speed` / `with_on_click` / `with_advance_after` to adjust the timing.
pub fn Transition::of_kind(kind : TransitionKind) -> Transition {
  {
    kind,
    speed: Fast,
    advance_on_click: true,
    advance_after: None,
    extension: [],
  }
}

///|
/// A transition wrapper with no effect — `<p:transition>` carrying only
/// timing. Useful to make a slide auto-advance without a visible effect.
pub fn Transition::none() -> Transition {
  Transition::of_kind(NoEffect)
}

///|
/// A fade transition (`<p:fade>`). `through_black` fades out to black before
/// fading in the next slide (the `thruBlk` attribute).
pub fn Transition::fade(through_black? : Bool = false) -> Transition {
  Transition::of_kind(Fade(through_black))
}

///|
/// A cut transition (`<p:cut>`). `through_black` cuts via a black frame.
pub fn Transition::cut(through_black? : Bool = false) -> Transition {
  Transition::of_kind(Cut(through_black))
}

///|
/// A push transition (`<p:push>`): the new slide pushes the old one off in the
/// given direction.
pub fn Transition::push(dir : TransitionSide) -> Transition {
  Transition::of_kind(Push(dir))
}

///|
/// A wipe transition (`<p:wipe>`) in the given direction.
pub fn Transition::wipe(dir : TransitionSide) -> Transition {
  Transition::of_kind(Wipe(dir))
}

///|
/// A cover transition (`<p:cover>`): the new slide slides in over the old one
/// from the given (eight-way) direction.
pub fn Transition::cover(dir : TransitionDirection) -> Transition {
  Transition::of_kind(Cover(dir))
}

///|
/// A split transition (`<p:split>`): split horizontally / vertically, opening
/// `Out` or closing `In`.
pub fn Transition::split(
  orient : TransitionOrientation,
  dir : TransitionInOut,
) -> Transition {
  Transition::of_kind(Split(orient, dir))
}

///|
/// A zoom transition (`<p:zoom>`): zoom `In` or `Out`.
pub fn Transition::zoom(dir : TransitionInOut) -> Transition {
  Transition::of_kind(Zoom(dir))
}

///|
/// A dissolve transition (`<p:dissolve>`).
pub fn Transition::dissolve() -> Transition {
  Transition::of_kind(Dissolve)
}

///|
/// Return a copy with the transition speed set.
pub fn Transition::with_speed(
  self : Transition,
  speed : TransitionSpeed,
) -> Transition {
  { ..self, speed, }
}

///|
/// Return a copy with the advance-on-click flag set. Set `false` together with
/// `with_advance_after` for kiosk-style auto-advancing decks.
pub fn Transition::with_on_click(
  self : Transition,
  on_click : Bool,
) -> Transition {
  { ..self, advance_on_click: on_click }
}

///|
/// Return a copy that auto-advances the slide after `ms` milliseconds (the
/// `advTm` attribute).
pub fn Transition::with_advance_after(
  self : Transition,
  ms : Int,
) -> Transition {
  { ..self, advance_after: Some(ms) }
}

///|
/// Return a copy with any timed auto-advance removed (the slide advances only
/// on click again).
pub fn Transition::without_advance_after(self : Transition) -> Transition {
  { ..self, advance_after: None }
}

// --- Slide builders (immutable, ADR-003) ---

///|
/// Return a new `Slide` with the given transition. Replaces any existing one.
pub fn Slide::with_transition(self : Slide, transition : Transition) -> Slide {
  { ..self, transition: Some(transition) }
}

///|
/// Return a new `Slide` with no transition — it shows with no entrance effect.
/// Clears any previously set transition.
pub fn Slide::without_transition(self : Slide) -> Slide {
  { ..self, transition: None }
}
