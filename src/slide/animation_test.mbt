// Tests for the animation DSL — typed `<p:timing>`.

///|
/// Serialise a slide to an XML string for structural assertions.
fn anim_xml(slide : @slide.Slide) -> String raise {
  @oxml.bytes_to_string(slide.serialize())
}

///|
/// Naive substring test (the slide test package has no `String::contains`).
fn has(haystack : String, needle : String) -> Bool {
  let h : Array[Char] = []
  for c in haystack {
    h.push(c)
  }
  let n : Array[Char] = []
  for c in needle {
    n.push(c)
  }
  let mut i = 0
  while i + n.length() <= h.length() {
    let mut j = 0
    while j < n.length() && h[i + j] == n[j] {
      j = j + 1
    }
    if j == n.length() {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Count non-overlapping occurrences of `needle` in `haystack`.
fn count(haystack : String, needle : String) -> Int {
  let h : Array[Char] = []
  for c in haystack {
    h.push(c)
  }
  let n : Array[Char] = []
  for c in needle {
    n.push(c)
  }
  let mut total = 0
  let mut i = 0
  while i + n.length() <= h.length() {
    let mut j = 0
    while j < n.length() && h[i + j] == n[j] {
      j = j + 1
    }
    if j == n.length() {
      total = total + 1
      i = i + n.length()
    } else {
      i = i + 1
    }
  }
  total
}

///|
/// A real parsed slide (the title-slide fixture already carries a `<p:timing>`
/// in `extension`, which `with_animations` must strip when a typed timeline is set).
fn anim_base_slide() -> @slide.Slide raise {
  @slide.Slide::parse(typical_title_slide())
}

// --- Direction / orientation filter words ---

///|
test "AnimDirection / AnimOrientation map to their filter words" {
  assert_eq(@slide.AnimDirection::Up.to_filter(), "up")
  assert_eq(@slide.AnimDirection::Down.to_filter(), "down")
  assert_eq(@slide.AnimDirection::Left.to_filter(), "left")
  assert_eq(@slide.AnimDirection::Right.to_filter(), "right")
  assert_eq(@slide.AnimOrientation::Horizontal.to_filter(), "horizontal")
  assert_eq(@slide.AnimOrientation::Vertical.to_filter(), "vertical")
}

// --- VisualEffect metadata ---

///|
test "VisualEffect::filter maps each effect to its DrawingML filter" {
  assert_eq(@slide.VisualEffect::Fade.filter().unwrap(), "fade")
  assert_eq(@slide.VisualEffect::Wipe(Up).filter().unwrap(), "wipe(up)")
  assert_eq(@slide.VisualEffect::Wipe(Right).filter().unwrap(), "wipe(right)")
  assert_eq(
    @slide.VisualEffect::Blinds(Vertical).filter().unwrap(),
    "blinds(vertical)",
  )
  assert_eq(
    @slide.VisualEffect::RandomBars(Horizontal).filter().unwrap(),
    "randombar(horizontal)",
  )
  assert_eq(@slide.VisualEffect::Dissolve.filter().unwrap(), "dissolve")
  assert_eq(@slide.VisualEffect::Wedge.filter().unwrap(), "wedge")
  assert_eq(@slide.VisualEffect::Wheel(8).filter().unwrap(), "wheel(8)")
  // Appear is a bare <p:set> — no animEffect filter.
  assert_true(@slide.VisualEffect::Appear.filter() is None)
}

///|
test "VisualEffect::preset_id matches the entrance preset numbering" {
  assert_eq(@slide.VisualEffect::Appear.preset_id(), 1)
  assert_eq(@slide.VisualEffect::Fade.preset_id(), 10)
  assert_eq(@slide.VisualEffect::Wipe(Up).preset_id(), 22)
  assert_eq(@slide.VisualEffect::Wheel(4).preset_id(), 21)
}

// --- Slide builders ---

///|
test "Slide::with_animations sets the typed field and strips extension timing" {
  let base = anim_base_slide()
  // The fixture parsed its <p:timing> into extension; the typed field is None.
  assert_true(base.timing is None)
  assert_true(
    base.extension.map(fn(e) { e.name.local_name }).contains("timing"),
  )
  let animated = base.with_animations(
    @slide.Timeline::new().on_click(@slide.Entrance(@slide.Fade), 2),
  )
  assert_true(animated.timing is Some(_))
  // The captured <p:timing> is gone — the typed timeline is the single source.
  assert_false(
    animated.extension.map(fn(e) { e.name.local_name }).contains("timing"),
  )
}

///|
test "Slide::without_animations clears the typed field and extension timing" {
  let base = anim_base_slide()
  let cleared = base
    .with_animations(
      @slide.Timeline::new().on_click(@slide.Entrance(@slide.Fade), 2),
    )
    .without_animations()
  assert_true(cleared.timing is None)
  assert_false(
    cleared.extension.map(fn(e) { e.name.local_name }).contains("timing"),
  )
}

///|
test "Slide::with_animations emits exactly one <p:timing> (no double-emit)" {
  let base = anim_base_slide()
  let animated = base.with_animations(
    @slide.Timeline::new().on_click(@slide.Entrance(@slide.Fade), 2),
  )
  let xml = anim_xml(animated)
  assert_eq(count(xml, "<p:timing>"), 1)
}

// --- Generated structure ---

///|
test "timing: entrance emits the canonical main-sequence scaffold" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(@slide.Entrance(@slide.Fade), 7),
    ),
  )
  assert_true(has(xml, "nodeType=\"tmRoot\""))
  assert_true(has(xml, "nodeType=\"mainSeq\""))
  assert_true(has(xml, "nodeType=\"clickEffect\""))
  assert_true(has(xml, "presetClass=\"entr\""))
  assert_true(has(xml, "presetID=\"10\""))
  assert_true(has(xml, "filter=\"fade\""))
  assert_true(has(xml, "transition=\"in\""))
  // Entrance reveals the shape.
  assert_true(has(xml, "<p:strVal val=\"visible\"/>"))
  // Targets the requested shape id.
  assert_true(has(xml, "<p:spTgt spid=\"7\"/>"))
  // The sequence navigation conditions are present.
  assert_true(has(xml, "<p:prevCondLst>"))
  assert_true(has(xml, "<p:nextCondLst>"))
}

///|
test "timing: exit plays out and hides the shape" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(@slide.Exit(@slide.Wipe(@slide.Down)), 3),
    ),
  )
  assert_true(has(xml, "presetClass=\"exit\""))
  assert_true(has(xml, "transition=\"out\""))
  assert_true(has(xml, "filter=\"wipe(down)\""))
  // Exit hides the shape at the end.
  assert_true(has(xml, "<p:strVal val=\"hidden\"/>"))
}

///|
test "timing: Appear is a bare <p:set> with no <p:animEffect>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(@slide.Entrance(@slide.Appear), 2),
    ),
  )
  assert_true(has(xml, "<p:strVal val=\"visible\"/>"))
  assert_false(has(xml, "<p:animEffect"))
}

///|
test "timing: start modes map to clickEffect / afterEffect / withEffect" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(@slide.Entrance(@slide.Fade), 2)
    .after_previous(@slide.Entrance(@slide.Fade), 3)
    .with_previous(@slide.Entrance(@slide.Fade), 4)
  let xml = anim_xml(base.with_animations(tl))
  assert_true(has(xml, "nodeType=\"clickEffect\""))
  assert_true(has(xml, "nodeType=\"afterEffect\""))
  assert_true(has(xml, "nodeType=\"withEffect\""))
  // The click group waits for a click (delay indefinite); the after-previous
  // group auto-starts (delay 0).
  assert_true(has(xml, "<p:cond delay=\"indefinite\"/>"))
}

///|
test "timing: a leading with_previous step behaves like on_click" {
  let base = anim_base_slide()
  // No prior step to attach to → opens a click group.
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().with_previous(@slide.Entrance(@slide.Fade), 2),
    ),
  )
  assert_true(has(xml, "nodeType=\"clickEffect\""))
  assert_false(has(xml, "nodeType=\"withEffect\""))
}

// --- Emphasis effects ---

///|
test "EmphasisEffect::preset_id classifies each emphasis" {
  assert_eq(@slide.EmphasisEffect::Spin(360).preset_id(), 8)
  assert_eq(@slide.EmphasisEffect::GrowShrink(150).preset_id(), 6)
  assert_eq(
    @slide.EmphasisEffect::ChangeFillColor(@units.RgbColor::new(0, 0, 0)).preset_id(),
    4,
  )
}

///|
test "timing: Spin emphasis emits <p:animRot> on the rotation attribute" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        @slide.Emphasis(@slide.Spin(360)),
        2,
        duration_ms=2000,
      ),
    ),
  )
  assert_true(has(xml, "presetClass=\"emph\""))
  // 360° in 60000ths of a degree.
  assert_true(has(xml, "<p:animRot by=\"21600000\">"))
  assert_true(has(xml, "<p:attrName>r</p:attrName>"))
  assert_true(has(xml, "dur=\"2000\""))
  // Emphasis does not toggle visibility.
  assert_false(has(xml, "style.visibility"))
}

///|
test "timing: GrowShrink emphasis emits <p:animScale> with a <p:by>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        @slide.Emphasis(@slide.GrowShrink(150)),
        5,
      ),
    ),
  )
  assert_true(has(xml, "<p:animScale>"))
  // 150% in 1000ths of a percent.
  assert_true(has(xml, "<p:by x=\"150000\" y=\"150000\"/>"))
  assert_true(has(xml, "<p:spTgt spid=\"5\"/>"))
}

///|
test "timing: ChangeFillColor emphasis emits <p:animClr> to an <a:srgbClr>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        @slide.Emphasis(@slide.ChangeFillColor(@units.RgbColor::new(255, 0, 0))),
        2,
      ),
    ),
  )
  assert_true(has(xml, "<p:animClr clrSpc=\"rgb\">"))
  assert_true(has(xml, "<a:srgbClr val=\"FF0000\"/>"))
  assert_true(has(xml, "<p:attrName>fillColor</p:attrName>"))
}

///|
test "timing: emphasis composes with entrance in one timeline" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(@slide.Entrance(@slide.Fade), 2)
    .after_previous(@slide.Emphasis(@slide.Spin(720)), 2, duration_ms=1500)
  let xml = anim_xml(base.with_animations(tl))
  assert_true(has(xml, "presetClass=\"entr\""))
  assert_true(has(xml, "presetClass=\"emph\""))
  // 720° = two turns.
  assert_true(has(xml, "<p:animRot by=\"43200000\">"))
}

// --- Fly In / Fly Out ---

///|
test "VisualEffect: FlyIn classifies as a fly, not a filter" {
  assert_true(@slide.VisualEffect::FlyIn(Left).fly_direction() is Some(Left))
  assert_true(@slide.VisualEffect::FlyIn(Left).filter() is None)
  assert_eq(@slide.VisualEffect::FlyIn(Up).preset_id(), 2)
  // A filter effect has no fly direction.
  assert_true(@slide.VisualEffect::Fade.fly_direction() is None)
}

///|
test "timing: FlyIn entrance moves ppt_x from off-slide to home" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        @slide.Entrance(@slide.FlyIn(@slide.Left)),
        5,
      ),
    ),
  )
  assert_true(has(xml, "presetClass=\"entr\""))
  // Reveal + a positional <p:anim> on ppt_x (no <p:animEffect> filter).
  assert_true(has(xml, "<p:strVal val=\"visible\"/>"))
  assert_true(has(xml, "<p:anim calcmode=\"lin\" valueType=\"num\">"))
  assert_true(has(xml, "<p:attrName>ppt_x</p:attrName>"))
  assert_true(has(xml, "<p:strVal val=\"0-#ppt_w/2\"/>"))
  assert_true(has(xml, "<p:strVal val=\"#ppt_x\"/>"))
  assert_false(has(xml, "<p:animEffect"))
}

///|
test "timing: FlyOut exit moves home to off-slide then hides" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(@slide.Exit(@slide.FlyIn(@slide.Down)), 5),
    ),
  )
  assert_true(has(xml, "presetClass=\"exit\""))
  assert_true(has(xml, "<p:attrName>ppt_y</p:attrName>"))
  // Off-slide value at the END (tm=100000) for a fly-out below the slide.
  assert_true(has(xml, "<p:strVal val=\"1+#ppt_h/2\"/>"))
  // Exit hides the shape afterwards.
  assert_true(has(xml, "<p:strVal val=\"hidden\"/>"))
}

///|
test "timing: each fly direction targets the right axis + off-slide value" {
  let base = anim_base_slide()
  fn fly_xml(dir : @slide.AnimDirection) -> String raise {
    anim_xml(
      base.with_animations(
        @slide.Timeline::new().on_click(@slide.Entrance(@slide.FlyIn(dir)), 2),
      ),
    )
  }

  assert_true(has(fly_xml(Right), "<p:strVal val=\"1+#ppt_w/2\"/>"))
  assert_true(has(fly_xml(Right), "<p:attrName>ppt_x</p:attrName>"))
  assert_true(has(fly_xml(Up), "<p:strVal val=\"0-#ppt_h/2\"/>"))
  assert_true(has(fly_xml(Up), "<p:attrName>ppt_y</p:attrName>"))
}

// --- Motion paths ---

///|
test "MotionPath::to_path_string formats the animMotion mini-language" {
  // Move, line, cubic curve, close — terminated by the E end marker.
  let p = @slide.MotionPath::new()
    .move_to(0.0, 0.0)
    .line_to(0.3, 0.1)
    .curve_to(0.4, 0.2, 0.5, 0.0, 0.6, 0.1)
    .close()
  assert_eq(p.to_path_string(), "M 0 0 L 0.3 0.1 C 0.4 0.2 0.5 0 0.6 0.1 Z E")
}

///|
test "MotionPath::line is a one-segment relative move" {
  assert_eq(
    @slide.MotionPath::line(0.25, -0.1).to_path_string(),
    "M 0 0 L 0.25 -0.1 E",
  )
}

///|
test "timing: motion emits <p:animMotion> with the path + ppt_x/ppt_y" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        @slide.Motion(@slide.MotionPath::line(0.3, 0.1)),
        5,
        duration_ms=2000,
      ),
    ),
  )
  assert_true(has(xml, "presetClass=\"path\""))
  assert_true(
    has(
      xml, "<p:animMotion origin=\"layout\" path=\"M 0 0 L 0.3 0.1 E\" pathEditMode=\"relative\">",
    ),
  )
  assert_true(has(xml, "<p:attrName>ppt_x</p:attrName>"))
  assert_true(has(xml, "<p:attrName>ppt_y</p:attrName>"))
  assert_true(has(xml, "<p:spTgt spid=\"5\"/>"))
  // Motion does not toggle visibility.
  assert_false(has(xml, "style.visibility"))
}

///|
test "timing: motion composes after an entrance in one timeline" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(@slide.Entrance(@slide.Fade), 2)
    .after_previous(
      @slide.Motion(
        @slide.MotionPath::new()
        .move_to(0.0, 0.0)
        .curve_to(0.1, 0.1, 0.2, -0.1, 0.3, 0.0),
      ),
      2,
    )
  let xml = anim_xml(base.with_animations(tl))
  assert_true(has(xml, "presetClass=\"entr\""))
  assert_true(has(xml, "presetClass=\"path\""))
  assert_true(has(xml, "C 0.1 0.1 0.2 -0.1 0.3 0"))
}

// --- By-paragraph text builds ---

///|
test "timing: a paragraph-targeted effect emits a <p:pRg> + a <p:bldP>" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(@slide.Entrance(@slide.Fade), 3, paragraph=0)
    .on_click(@slide.Entrance(@slide.Fade), 3, paragraph=1)
  let xml = anim_xml(base.with_animations(tl))
  // Each effect targets a paragraph range, not the whole shape.
  assert_true(has(xml, "<p:txEl><p:pRg st=\"0\" end=\"0\"/></p:txEl>"))
  assert_true(has(xml, "<p:txEl><p:pRg st=\"1\" end=\"1\"/></p:txEl>"))
  // The shape is declared as a by-paragraph build.
  assert_true(has(xml, "<p:bldLst>"))
  assert_true(has(xml, "<p:bldP spid=\"3\" grpId=\"1\" build=\"p\"/>"))
}

///|
test "timing: a whole-shape effect has no <p:pRg> and no <p:bldLst>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(@slide.Entrance(@slide.Fade), 2),
    ),
  )
  assert_false(has(xml, "<p:pRg"))
  assert_false(has(xml, "<p:bldLst>"))
}

///|
test "timing: build-group ids match between paragraph effects and their <p:bldP>" {
  let base = anim_base_slide()
  // Two shapes built by paragraph → distinct grpIds 1 and 2; a whole-shape
  // effect stays in group 0.
  let tl = @slide.Timeline::new()
    .on_click(@slide.Entrance(@slide.Fade), 3, paragraph=0)
    .on_click(@slide.Entrance(@slide.Wipe(@slide.Up)), 4, paragraph=0)
    .with_previous(@slide.Emphasis(@slide.Spin(360)), 2)
  let xml = anim_xml(base.with_animations(tl))
  assert_true(has(xml, "<p:bldP spid=\"3\" grpId=\"1\" build=\"p\"/>"))
  assert_true(has(xml, "<p:bldP spid=\"4\" grpId=\"2\" build=\"p\"/>"))
  // The paragraph effects carry their shape's build grpId on the cTn.
  assert_true(has(xml, "grpId=\"1\""))
  assert_true(has(xml, "grpId=\"2\""))
  // The whole-shape emphasis stays in the default group 0.
  assert_true(has(xml, "grpId=\"0\""))
}

// --- Build-only round-trip ---

///|
test "timing: built timeline re-serialises stably (build-only round-trip)" {
  let base = anim_base_slide()
  let animated = base.with_animations(
    @slide.Timeline::new()
    .on_click(@slide.Entrance(@slide.FlyIn(@slide.Left)), 2)
    .with_previous(@slide.Emphasis(@slide.Spin(360)), 2)
    .after_previous(@slide.Motion(@slide.MotionPath::line(0.2, 0.0)), 2)
    .on_click(@slide.Entrance(@slide.Fade), 3, paragraph=0)
    .after_previous(@slide.Exit(@slide.Wipe(@slide.Up)), 3),
  )
  let xml1 = anim_xml(animated)
  // Parsing re-captures <p:timing> into extension; the typed field is None.
  let reparsed = @slide.Slide::parse(animated.serialize())
  assert_true(reparsed.timing is None)
  assert_true(
    reparsed.extension.map(fn(e) { e.name.local_name }).contains("timing"),
  )
  // …but the bytes are stable across the round trip.
  let xml2 = anim_xml(reparsed)
  assert_eq(xml1, xml2)
}

///|
test "timing: a slide with no animations emits no <p:timing> from the field" {
  // Fresh built slide (no fixture timing); ensure we don't emit an empty tree.
  let base = anim_base_slide().without_animations()
  assert_true(base.timing is None)
  // (Fixture timing was stripped by without_animations.)
  let xml = anim_xml(base)
  assert_false(has(xml, "<p:timing>"))
}
