// Tests for the typed slide transition (`<p:transition>`, roadmap v0.4 D3).
//
// Whole-value equality on the transition types goes through `assert_true(a ==
// b)` (they derive `Eq, Debug`, and `assert_eq` would additionally require
// `Show`), matching the `background_test.mbt` convention. Primitive fields use
// `assert_eq` directly.

///|
/// Wrap a `<p:transition>` string into a parseable `<p:sld>`. The transition
/// follows `<p:cSld>` per CT_Slide ordering. An empty `tr` yields a slide with
/// no transition.
fn slide_with_transition(tr : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/></p:spTree></p:cSld>" +
    tr +
    "</p:sld>"
  fixture_bytes(xml)
}

///|
/// Attach `t` to a minimal slide, serialise, and re-parse — the parser↔writer
/// round-trip used to assert model fidelity across every transition kind.
fn roundtrip_transition(
  t : @slide.Transition,
) -> @slide.Transition? raise @slide.SlideError {
  let base = @slide.Slide::parse(slide_with_transition(""))
  let bytes = base.with_transition(t).serialize()
  @slide.Slide::parse(bytes).transition
}

// --- parse: attributes ---

///|
test "transition: parse spd / advClick / advTm attributes" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition spd=\"slow\" advClick=\"0\" advTm=\"5000\"><p:push dir=\"r\"/></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => {
      assert_true(t.kind == Push(Right))
      assert_true(t.speed == Slow)
      assert_eq(t.advance_on_click, false)
      assert_true(t.advance_after == Some(5000))
    }
    None => fail("expected a transition")
  }
}

///|
test "transition: absent attributes fall back to schema defaults" {
  let slide = @slide.Slide::parse(
    slide_with_transition("<p:transition><p:fade/></p:transition>"),
  )
  match slide.transition {
    Some(t) => {
      assert_true(t.kind == Fade(false))
      assert_true(t.speed == Fast)
      assert_eq(t.advance_on_click, true)
      assert_true(t.advance_after is None)
    }
    None => fail("expected a transition")
  }
}

///|
test "transition: a slide with no <p:transition> has None" {
  let slide = @slide.Slide::parse(slide_with_transition(""))
  assert_true(slide.transition is None)
}

// --- parse: per-kind attribute decoding ---

///|
test "transition: fade thruBlk decodes" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:fade thruBlk=\"1\"/></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => assert_true(t.kind == Fade(true))
    None => fail("expected a transition")
  }
}

///|
test "transition: split orient + dir decode" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:split orient=\"vert\" dir=\"in\"/></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => assert_true(t.kind == Split(Vertical, In))
    None => fail("expected a transition")
  }
}

///|
test "transition: wheel spokes decode (explicit + default)" {
  let eight = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:wheel spokes=\"8\"/></p:transition>",
    ),
  )
  match eight.transition {
    Some(t) => assert_true(t.kind == Wheel(8))
    None => fail("expected a transition")
  }
  let dflt = @slide.Slide::parse(
    slide_with_transition("<p:transition><p:wheel/></p:transition>"),
  )
  match dflt.transition {
    Some(t) => assert_true(t.kind == Wheel(4))
    None => fail("expected a transition")
  }
}

///|
test "transition: cover eight-direction decodes corner value" {
  let slide = @slide.Slide::parse(
    slide_with_transition("<p:transition><p:cover dir=\"ru\"/></p:transition>"),
  )
  match slide.transition {
    Some(t) => assert_true(t.kind == Cover(RightUp))
    None => fail("expected a transition")
  }
}

// --- round-trip: every kind ---

///|
test "transition: round-trip across every kind" {
  let kinds : Array[@slide.TransitionKind] = [
    NoEffect,
    Blinds(Horizontal),
    Checker(Vertical),
    Circle,
    Comb(Horizontal),
    Cover(LeftDown),
    Cut(true),
    Diamond,
    Dissolve,
    Fade(false),
    Newsflash,
    Plus,
    Pull(RightUp),
    Push(Down),
    Random,
    RandomBar(Vertical),
    Split(Horizontal, Out),
    Strips(LeftUp),
    Wedge,
    Wheel(3),
    Wipe(Up),
    Zoom(In),
  ]
  for k in kinds {
    let t = @slide.Transition::of_kind(k)
    assert_true(roundtrip_transition(t) == Some(t))
  }
}

///|
test "transition: round-trip preserves speed + advance timing" {
  let t = @slide.Transition::push(Left)
    .with_speed(Medium)
    .with_on_click(false)
    .with_advance_after(3000)
  assert_true(roundtrip_transition(t) == Some(t))
}

// --- builders ---

///|
test "transition: of_kind applies schema defaults" {
  let t = @slide.Transition::of_kind(Dissolve)
  assert_true(t.kind == Dissolve)
  assert_true(t.speed == Fast)
  assert_eq(t.advance_on_click, true)
  assert_true(t.advance_after is None)
}

///|
test "transition: convenience constructors" {
  assert_true(@slide.Transition::fade().kind == Fade(false))
  assert_true(@slide.Transition::fade(through_black=true).kind == Fade(true))
  assert_true(@slide.Transition::cut().kind == Cut(false))
  assert_true(@slide.Transition::push(Right).kind == Push(Right))
  assert_true(@slide.Transition::wipe(Up).kind == Wipe(Up))
  assert_true(@slide.Transition::cover(LeftUp).kind == Cover(LeftUp))
  assert_true(
    @slide.Transition::split(Vertical, In).kind == Split(Vertical, In),
  )
  assert_true(@slide.Transition::zoom(Out).kind == Zoom(Out))
  assert_true(@slide.Transition::dissolve().kind == Dissolve)
  assert_true(@slide.Transition::none().kind == NoEffect)
}

///|
test "transition: timing builders" {
  let t = @slide.Transition::fade()
    .with_advance_after(2000)
    .with_on_click(false)
    .with_speed(Slow)
  assert_true(t.advance_after == Some(2000))
  assert_eq(t.advance_on_click, false)
  assert_true(t.speed == Slow)
  assert_true(t.without_advance_after().advance_after is None)
}

// --- Slide builders ---

///|
test "Slide::with_transition / without_transition" {
  let base = @slide.Slide::parse(slide_with_transition(""))
  let with_t = base.with_transition(@slide.Transition::wipe(Right))
  assert_true(with_t.transition == Some(@slide.Transition::wipe(Right)))
  assert_true(with_t.without_transition().transition is None)
  // with_transition replaces rather than stacks.
  let replaced = with_t.with_transition(@slide.Transition::fade())
  assert_true(replaced.transition == Some(@slide.Transition::fade()))
}

// --- attribute omission (canonical output) ---

///|
test "transition: default attributes are omitted on serialise" {
  let base = @slide.Slide::parse(slide_with_transition(""))
  // Fast + advance-on-click + no advTm: only the effect child should appear.
  let xml = @oxml.bytes_to_string(
    base.with_transition(@slide.Transition::fade()).serialize(),
  )
  assert_true(char_index_of(xml, "<p:transition>") >= 0)
  assert_eq(char_index_of(xml, "spd="), -1)
  assert_eq(char_index_of(xml, "advClick="), -1)
  // Non-default values are emitted.
  let xml2 = @oxml.bytes_to_string(
    base
    .with_transition(
      @slide.Transition::fade().with_speed(Slow).with_on_click(false),
    )
    .serialize(),
  )
  assert_true(char_index_of(xml2, "spd=\"slow\"") >= 0)
  assert_true(char_index_of(xml2, "advClick=\"0\"") >= 0)
}

// --- lossless preservation (ADR-004) ---

///|
test "transition: <p:sndAc> sound child preserved via extension" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:fade/><p:sndAc><p:stSnd><p:snd r:embed=\"rId9\"/></p:stSnd></p:sndAc></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => {
      assert_true(t.kind == Fade(false))
      assert_eq(t.extension.length(), 1)
      assert_eq(t.extension[0].name.local_name, "sndAc")
    }
    None => fail("expected a transition")
  }
  // And it survives a full round-trip.
  let again = @slide.Slide::parse(slide.serialize())
  assert_true(again.transition == slide.transition)
}
