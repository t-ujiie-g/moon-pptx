// Animation timing writer — synthesises `<p:timing>` from a typed `Timeline`
// (roadmap v0.5 D2). See `animation.mbt` for the model + scope.
//
// The timing tree is built as an `@xml.XmlElement` DOM and emitted through the
// shared `@oxml.write_xml_element` (which auto-declares namespaces), rather than
// imperative start/end calls — the structure is deep enough that a DOM reads far
// more clearly. The canonical scaffold PowerPoint emits for a click-driven main
// sequence is:
//
//   <p:timing><p:tnLst><p:par>
//     <p:cTn id=1 dur=indefinite restart=never nodeType=tmRoot><p:childTnLst>
//       <p:seq concurrent=1 nextAc=seek>
//         <p:cTn id=2 dur=indefinite nodeType=mainSeq><p:childTnLst>
//           {{ one click/after group <p:par> per group }}
//         </p:childTnLst>
//         <p:prevCondLst/><p:nextCondLst/></p:cTn>
//       </p:seq>
//     </p:childTnLst></p:cTn>
//   </p:par></p:tnLst></p:timing>
//
// Each group nests two fixed `<p:par>` levels (the click trigger, then a 0-delay
// holder) around one `<p:par>` per effect; each effect node carries the
// preset metadata and a `<p:childTnLst>` of behaviour elements (`<p:set>` /
// `<p:animEffect>`).

///|
/// `<p:animScale><p:by>` is expressed in 1000ths of a percent, so 150 % is
/// `150000`. (`<p:animRot by>` reuses `@units.ooxml_per_degree` instead.)
let anim_scale_per_percent : Int = 1000

///|
/// The end of an animation's normalised time line — `<p:tav tm>` runs `0`
/// (start) to `100000` (100 %).
let anim_time_end : String = "100000"

///|
/// Monotonic `<p:cTn id="…">` allocator. cTn ids must be unique within the
/// timing tree; PowerPoint emits them increasing in document order, which the
/// build order here preserves.
priv struct IdGen {
  mut n : Int
}

///|
fn IdGen::next(self : IdGen) -> Int {
  self.n = self.n + 1
  self.n
}

///|
/// One main-sequence group: its effects all start together. `is_click` selects
/// the trigger — a mouse click (start delay `indefinite`) vs. auto-advance after
/// the previous group (delay `0`).
priv struct AnimGroup {
  is_click : Bool
  steps : Array[AnimStep]
}

///|
/// Build a presentation-namespace element.
fn anim_el(
  name : String,
  attrs : Array[(String, String)],
  children : Array[@xml.XmlNode],
) -> @xml.XmlElement {
  let qattrs = attrs.map(fn(kv) { (@xml.QName::unqualified(kv.0), kv.1) })
  @xml.XmlElement::new(
    @xml.QName::new(@oxml.presentation_ns, name),
    qattrs,
    children,
  )
}

///|
/// `anim_el` wrapped as an `XmlNode` child.
fn anim_node(
  name : String,
  attrs : Array[(String, String)],
  children : Array[@xml.XmlNode],
) -> @xml.XmlNode {
  @xml.Element(anim_el(name, attrs, children))
}

///|
/// Partition the flat step list into main-sequence groups. `OnClick` /
/// `AfterPrevious` each open a new group; `WithPrevious` joins the current one
/// (or opens a click group if it is the very first step).
fn group_anim_steps(steps : Array[AnimStep]) -> Array[AnimGroup] {
  let groups : Array[AnimGroup] = []
  for step in steps {
    match step.start {
      OnClick => groups.push({ is_click: true, steps: [step] })
      AfterPrevious => groups.push({ is_click: false, steps: [step] })
      WithPrevious =>
        if groups.length() == 0 {
          groups.push({ is_click: true, steps: [step] })
        } else {
          groups[groups.length() - 1].steps.push(step)
        }
    }
  }
  groups
}

///|
/// A `<p:tgtEl>` pointing at the shape with id `spid`, or — when `paragraph` is
/// `Some(p)` — at that shape's `p`-th text paragraph (`<p:txEl><p:pRg>`).
fn anim_tgt(spid : String, paragraph : Int?) -> @xml.XmlNode {
  let sp_children : Array[@xml.XmlNode] = match paragraph {
    Some(p) =>
      [
        anim_node("txEl", [], [
          anim_node("pRg", [("st", p.to_string()), ("end", p.to_string())], []),
        ]),
      ]
    None => []
  }
  anim_node("tgtEl", [], [anim_node("spTgt", [("spid", spid)], sp_children)])
}

///|
/// A `<p:attrNameLst>` carrying one `<p:attrName>` per name.
fn anim_attr_names(names : Array[String]) -> @xml.XmlNode {
  anim_node(
    "attrNameLst",
    [],
    names.map(fn(n) { anim_node("attrName", [], [@xml.Text(n)]) }),
  )
}

///|
/// A `<p:attrNameLst>` carrying a single `<p:attrName>`.
fn anim_attr_name(name : String) -> @xml.XmlNode {
  anim_attr_names([name])
}

///|
/// A drawing-namespace `<a:srgbClr val="…"/>` (the colour child of `<p:to>` in
/// `<p:animClr>`).
fn anim_srgb(hex : String) -> @xml.XmlNode {
  @xml.Element(
    @xml.XmlElement::new(
      @xml.QName::new(@oxml.drawing_ns, "srgbClr"),
      [(@xml.QName::unqualified("val"), hex)],
      [],
    ),
  )
}

///|
/// The behaviour children of one effect node, dispatched by class. Entrance
/// reveals via a `<p:set>` then plays the filter `in`; exit plays it `out` then
/// hides; emphasis animates a property in place with no visibility change.
fn anim_behaviors(gen : IdGen, step : AnimStep) -> Array[@xml.XmlNode] {
  let spid = step.target_shape_id.to_string()
  let dur = step.duration_ms.to_string()
  // Every behaviour of this step targets the same element — the whole shape, or
  // one paragraph for a by-paragraph build.
  let tgt = anim_tgt(spid, step.paragraph)

  // <p:set> toggling style.visibility to `vis`, held from `delay`.
  fn set_node(vis : String, delay : String) -> @xml.XmlNode {
    anim_node("set", [], [
      anim_node("cBhvr", [], [
        anim_node(
          "cTn",
          [("id", gen.next().to_string()), ("dur", "1"), ("fill", "hold")],
          [
            anim_node("stCondLst", [], [
              anim_node("cond", [("delay", delay)], []),
            ]),
          ],
        ),
        tgt,
        anim_attr_name("style.visibility"),
      ]),
      anim_node("to", [], [anim_node("strVal", [("val", vis)], [])]),
    ])
  }

  // <p:animEffect transition=… filter=…> over `dur` ms.
  fn anim_effect_node(transition : String, f : String) -> @xml.XmlNode {
    anim_node("animEffect", [("transition", transition), ("filter", f)], [
      anim_node("cBhvr", [], [
        anim_node("cTn", [("id", gen.next().to_string()), ("dur", dur)], []),
        tgt,
      ]),
    ])
  }

  // <p:anim> moving the shape along one axis between an off-slide value and its
  // natural position — Fly In (`is_in`) starts off-slide, Fly Out ends off-slide.
  // The off-slide value follows PowerPoint's fly convention (half the shape's
  // own width/height past the edge), referencing `#ppt_w` / `#ppt_h`.
  fn fly_node(is_in : Bool, dir : AnimDirection) -> @xml.XmlNode {
    let (attr, off) = match dir {
      Left => ("ppt_x", "0-#ppt_w/2")
      Right => ("ppt_x", "1+#ppt_w/2")
      Up => ("ppt_y", "0-#ppt_h/2")
      Down => ("ppt_y", "1+#ppt_h/2")
    }
    let home = "#" + attr
    let (v0, v1) = if is_in { (off, home) } else { (home, off) }
    fn tav(tm : String, v : String) -> @xml.XmlNode {
      anim_node("tav", [("tm", tm)], [
        anim_node("val", [], [anim_node("strVal", [("val", v)], [])]),
      ])
    }

    anim_node("anim", [("calcmode", "lin"), ("valueType", "num")], [
      anim_node("cBhvr", [], [
        anim_node("cTn", [("id", gen.next().to_string()), ("dur", dur)], []),
        tgt,
        anim_attr_names([attr]),
      ]),
      anim_node("tavLst", [], [tav("0", v0), tav(anim_time_end, v1)]),
    ])
  }

  // <p:animMotion> travelling the given path (relative to the shape's start).
  fn motion_node(path : MotionPath) -> @xml.XmlNode {
    anim_node(
      "animMotion",
      [
        ("origin", "layout"),
        ("path", path.to_path_string()),
        ("pathEditMode", "relative"),
      ],
      [
        anim_node("cBhvr", [], [
          anim_node(
            "cTn",
            [("id", gen.next().to_string()), ("dur", dur), ("fill", "hold")],
            [],
          ),
          tgt,
          anim_attr_names(["ppt_x", "ppt_y"]),
        ]),
      ],
    )
  }

  // A held <p:cBhvr> for an emphasis behaviour: <p:cTn dur=… fill=hold> + tgt +
  // optional attrNameLst.
  fn emph_cbhvr(attr : String?) -> @xml.XmlNode {
    let children = [
      anim_node(
        "cTn",
        [("id", gen.next().to_string()), ("dur", dur), ("fill", "hold")],
        [],
      ),
      tgt,
    ]
    match attr {
      Some(a) => children.push(anim_attr_name(a))
      None => ()
    }
    anim_node("cBhvr", [], children)
  }

  match step.effect {
    Entrance(e) => {
      // Reveal at the start, then play the motion: a fly-in <p:anim>, a filter
      // <p:animEffect>, or nothing (Appear is the bare set).
      let nodes = [set_node("visible", "0")]
      match e.fly_direction() {
        Some(dir) => nodes.push(fly_node(true, dir))
        None =>
          match e.filter() {
            Some(f) => nodes.push(anim_effect_node("in", f))
            None => ()
          }
      }
      nodes
    }
    Exit(e) =>
      // Play the motion out, then hide once it ends (instant for Disappear).
      match e.fly_direction() {
        Some(dir) => [fly_node(false, dir), set_node("hidden", dur)]
        None =>
          match e.filter() {
            Some(f) => [anim_effect_node("out", f), set_node("hidden", dur)]
            None => [set_node("hidden", "0")]
          }
      }
    Emphasis(Spin(degrees)) =>
      // <p:animRot by="…"> — rotation in OOXML 1/60000-degree units.
      [
        anim_node(
          "animRot",
          [("by", (degrees * @units.ooxml_per_degree).to_string())],
          [emph_cbhvr(Some("r"))],
        ),
      ]
    Emphasis(GrowShrink(percent)) => {
      // <p:animScale> with <p:by x/y> in 1000ths of a percent.
      let v = (percent * anim_scale_per_percent).to_string()
      [
        anim_node("animScale", [], [
          emph_cbhvr(None),
          anim_node("by", [("x", v), ("y", v)], []),
        ]),
      ]
    }
    Emphasis(ChangeFillColor(color)) =>
      // <p:animClr clrSpc="rgb"> to an <a:srgbClr>.
      [
        anim_node("animClr", [("clrSpc", "rgb")], [
          emph_cbhvr(Some("fillColor")),
          anim_node("to", [], [anim_srgb(color.to_hex())]),
        ]),
      ]
    Motion(path) => [motion_node(path)]
  }
}

///|
/// One effect `<p:par>`: the preset-bearing `<p:cTn>` (nodeType per position in
/// its group) wrapping its behaviour children.
fn anim_effect_par(
  gen : IdGen,
  step : AnimStep,
  node_type : String,
  grpid_of : (Int) -> Int,
) -> @xml.XmlNode {
  let (preset_class, preset_id) = match step.effect {
    Entrance(e) => ("entr", e.preset_id())
    Exit(e) => ("exit", e.preset_id())
    Emphasis(e) => ("emph", e.preset_id())
    // Custom freeform motion path — presetID 0 = no named preset; PowerPoint
    // labels it "Custom Path" and renders from the `path` attribute.
    Motion(_) => ("path", 0)
  }
  // Whole-shape effects sit in the default group 0; a by-paragraph build links
  // each paragraph effect to its shape's build group (matching the <p:bldP>).
  let grp_id = match step.paragraph {
    Some(_) => grpid_of(step.target_shape_id)
    None => 0
  }
  let eff_id = gen.next()
  let behaviors = anim_behaviors(gen, step)
  anim_node("par", [], [
    anim_node(
      "cTn",
      [
        ("id", eff_id.to_string()),
        ("presetID", preset_id.to_string()),
        ("presetClass", preset_class),
        ("presetSubtype", "0"),
        ("fill", "hold"),
        ("grpId", grp_id.to_string()),
        ("nodeType", node_type),
      ],
      [
        anim_node("stCondLst", [], [anim_node("cond", [("delay", "0")], [])]),
        anim_node("childTnLst", [], behaviors),
      ],
    ),
  ])
}

///|
/// One main-sequence group `<p:par>` — the click/after trigger wrapping the
/// 0-delay holder wrapping each effect par.
fn anim_group_par(
  gen : IdGen,
  group : AnimGroup,
  grpid_of : (Int) -> Int,
) -> @xml.XmlNode {
  let trigger_id = gen.next()
  let holder_id = gen.next()
  let trigger_delay = if group.is_click { "indefinite" } else { "0" }
  let effect_pars : Array[@xml.XmlNode] = []
  for i, step in group.steps {
    let node_type = if i == 0 {
      if group.is_click {
        "clickEffect"
      } else {
        "afterEffect"
      }
    } else {
      "withEffect"
    }
    effect_pars.push(anim_effect_par(gen, step, node_type, grpid_of))
  }
  anim_node("par", [], [
    anim_node("cTn", [("id", trigger_id.to_string()), ("fill", "hold")], [
      anim_node("stCondLst", [], [
        anim_node("cond", [("delay", trigger_delay)], []),
      ]),
      anim_node("childTnLst", [], [
        anim_node("par", [], [
          anim_node("cTn", [("id", holder_id.to_string()), ("fill", "hold")], [
            anim_node("stCondLst", [], [anim_node("cond", [("delay", "0")], [])]),
            anim_node("childTnLst", [], effect_pars),
          ]),
        ]),
      ]),
    ]),
  ])
}

///|
/// A sequence-level condition list (`<p:prevCondLst>` / `<p:nextCondLst>`)
/// firing on the given slide-navigation event.
fn anim_seq_cond(name : String, evt : String) -> @xml.XmlNode {
  anim_node(name, [], [
    anim_node("cond", [("evt", evt), ("delay", "0")], [
      anim_node("tgtEl", [], [anim_node("sldTgt", [], [])]),
    ]),
  ])
}

///|
/// Build the full `<p:timing>` element for a timeline.
fn timing_element(timeline : Timeline) -> @xml.XmlElement {
  let gen : IdGen = { n: 0 }
  let groups = group_anim_steps(timeline.steps)
  // Shapes with a by-paragraph effect, in first-seen order; each gets a build
  // group id (its index + 1, so they never collide with the default group 0).
  let build_shapes : Array[Int] = []
  for step in timeline.steps {
    if step.paragraph is Some(_) && !build_shapes.contains(step.target_shape_id) {
      build_shapes.push(step.target_shape_id)
    }
  }
  let grpid_of = fn(spid : Int) -> Int {
    for i, s in build_shapes {
      if s == spid {
        return i + 1
      }
    }
    0
  }
  let root_id = gen.next() // 1 — tmRoot
  let seq_id = gen.next() // 2 — mainSeq
  let group_pars = groups.map(fn(g) { anim_group_par(gen, g, grpid_of) })
  // <p:tnLst> followed by an optional <p:bldLst> declaring each by-paragraph
  // build (CT_SlideTiming order: tnLst, bldLst).
  let timing_children = [
    anim_node("tnLst", [], [
      anim_node("par", [], [
        anim_node(
          "cTn",
          [
            ("id", root_id.to_string()),
            ("dur", "indefinite"),
            ("restart", "never"),
            ("nodeType", "tmRoot"),
          ],
          [
            anim_node("childTnLst", [], [
              anim_node("seq", [("concurrent", "1"), ("nextAc", "seek")], [
                anim_node(
                  "cTn",
                  [
                    ("id", seq_id.to_string()),
                    ("dur", "indefinite"),
                    ("nodeType", "mainSeq"),
                  ],
                  [anim_node("childTnLst", [], group_pars)],
                ),
                anim_seq_cond("prevCondLst", "onPrev"),
                anim_seq_cond("nextCondLst", "onNext"),
              ]),
            ]),
          ],
        ),
      ]),
    ]),
  ]
  if build_shapes.length() > 0 {
    let bld_ps = build_shapes.map(fn(spid) {
      anim_node(
        "bldP",
        [
          ("spid", spid.to_string()),
          ("grpId", grpid_of(spid).to_string()),
          ("build", "p"),
        ],
        [],
      )
    })
    timing_children.push(anim_node("bldLst", [], bld_ps))
  }
  anim_el("timing", [], timing_children)
}

///|
/// Emit `<p:timing>` for a slide's typed timeline. Slotted after
/// `<p:transition>`, per CT_Slide ordering.
fn write_timing(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  timeline : Timeline,
) -> Unit raise @xml.XmlError {
  @oxml.write_xml_element(w, ctx, timing_element(timeline))
}
