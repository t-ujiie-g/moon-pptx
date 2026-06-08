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
/// A `<p:tgtEl>` pointing at the shape with id `spid`.
fn anim_tgt(spid : String) -> @xml.XmlNode {
  anim_node("tgtEl", [], [anim_node("spTgt", [("spid", spid)], [])])
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
        anim_tgt(spid),
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
        anim_tgt(spid),
      ]),
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
          anim_tgt(spid),
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
      anim_tgt(spid),
    ]
    match attr {
      Some(a) => children.push(anim_attr_name(a))
      None => ()
    }
    anim_node("cBhvr", [], children)
  }

  match step.effect {
    Entrance(e) => {
      // Reveal at the start, then play the filter in.
      let nodes = [set_node("visible", "0")]
      match e.filter() {
        Some(f) => nodes.push(anim_effect_node("in", f))
        None => ()
      }
      nodes
    }
    Exit(e) =>
      // Play the filter out, then hide once it ends (instant for Appear).
      match e.filter() {
        Some(f) => [anim_effect_node("out", f), set_node("hidden", dur)]
        None => [set_node("hidden", "0")]
      }
    Emphasis(Spin(degrees)) =>
      // <p:animRot by="degrees*60000"> on the rotation attribute `r`.
      [
        anim_node("animRot", [("by", (degrees * 60000).to_string())], [
          emph_cbhvr(Some("r")),
        ]),
      ]
    Emphasis(GrowShrink(percent)) => {
      // <p:animScale> with <p:by x/y> in 1000ths of a percent.
      let v = (percent * 1000).to_string()
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
) -> @xml.XmlNode {
  let (preset_class, preset_id) = match step.effect {
    Entrance(e) => ("entr", e.preset_id())
    Exit(e) => ("exit", e.preset_id())
    Emphasis(e) => ("emph", e.preset_id())
    // Custom freeform motion path — presetID 0 = no named preset; PowerPoint
    // labels it "Custom Path" and renders from the `path` attribute.
    Motion(_) => ("path", 0)
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
        ("grpId", "0"),
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
fn anim_group_par(gen : IdGen, group : AnimGroup) -> @xml.XmlNode {
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
    effect_pars.push(anim_effect_par(gen, step, node_type))
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
  let root_id = gen.next() // 1 — tmRoot
  let seq_id = gen.next() // 2 — mainSeq
  let group_pars = groups.map(fn(g) { anim_group_par(gen, g) })
  anim_el("timing", [], [
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
  ])
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
