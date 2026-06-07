// Slide XML writer (top-level + spTree dispatch).
//
// Mirrors `parser.mbt`. Each `write_*` helper opens its element, emits
// child content, and closes the matching EndElement. The slide-level
// `extension` array carries a mix of elements that need to be re-emitted
// at three different nesting levels (sld / cSld / spTree); we classify
// each captured element by its local-name and replay it under the right
// parent. Foreign-namespace extensions go to the sld level.

///|
/// Where in the sld → cSld → spTree nesting a captured extension
/// element belongs, based on its local-name. Drives the three-pass
/// replay in `write_slide_xml`.
priv enum ExtScope {
  ExtSpTree
  ExtCSld
  ExtSld
}

///|
/// Classify a captured extension element by its OOXML local name.
///
/// `<p:nvGrpSpPr>` / `<p:grpSpPr>` belong inside `<p:spTree>`;
/// `<p:controls>` belongs inside `<p:cSld>`; everything else
/// (`<p:timing>` / `<p:custDataLst>` / `<p:extLst>` + foreign-namespace
/// siblings) attaches at the sld level. `<p:bg>` (roadmap A7) and
/// `<p:transition>` (roadmap D3) are no longer captured here — they are the
/// typed `Slide.background` / `Slide.transition` fields. Same applies for
/// `<p:notes>` since they share the content model.
fn classify_ext(el : @xml.XmlElement) -> ExtScope {
  if el.name.uri != @oxml.presentation_ns {
    return ExtSld
  }
  match el.name.local_name {
    "nvGrpSpPr" | "grpSpPr" => ExtSpTree
    "controls" => ExtCSld
    _ => ExtSld
  }
}

///|
/// Emit `<p:bg>` (CT_Background) — the typed slide background. Per
/// ECMA-376's CT_CommonSlideData ordering, `<p:bg>` precedes `<p:spTree>`.
fn write_bg(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  bg : Background,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "bg"))
  match bg {
    Properties(p) => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "bgPr"))
      if p.shade_to_title {
        w.attribute(@xml.QName::unqualified("shadeToTitle"), "1")
      }
      match p.fill {
        Some(f) => @oxml.write_fill(w, ctx, f)
        None => ()
      }
      match p.effects {
        Some(e) => @oxml.write_effect_list(w, ctx, e)
        None => ()
      }
      // grpFill / effectDag / extLst captured per ADR-004.
      for ext in p.extension {
        @oxml.write_xml_element(w, ctx, ext)
      }
      w.end_element() // bgPr
    }
    StyleReference(idx, color) => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "bgRef"))
      w.attribute(@xml.QName::unqualified("idx"), idx.to_string())
      @oxml.write_color(w, ctx, color)
      w.end_element() // bgRef
    }
  }
  w.end_element() // bg
}

///|
/// Emit `<p:transition>` (CT_SlideTransition) — the typed slide transition
/// (roadmap D3). Default-valued attributes (`spd="fast"`, `advClick="1"`) are
/// omitted; they re-parse to the same model. The single effect child precedes
/// the preserved `<p:sndAc>` / `<p:extLst>` extensions.
fn write_transition(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  t : Transition,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "transition"))
  if t.speed != Fast {
    w.attribute(@xml.QName::unqualified("spd"), t.speed.to_xml())
  }
  if !t.advance_on_click {
    w.attribute(@xml.QName::unqualified("advClick"), "0")
  }
  match t.advance_after {
    Some(ms) => w.attribute(@xml.QName::unqualified("advTm"), ms.to_string())
    None => ()
  }
  write_transition_kind(w, t.kind)
  // <p:sndAc> / <p:extLst> captured per ADR-004.
  for ext in t.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element() // transition
}

///|
/// Emit the single transition-effect child element. `NoEffect` emits nothing
/// (the `<p:transition>` carries only timing). Each effect element is a leaf
/// carrying its direction / orientation / flag attribute.
fn write_transition_kind(
  w : @xml.XmlWriter,
  kind : TransitionKind,
) -> Unit raise @xml.XmlError {
  // Open a `<p:NAME>` effect element with a single `dir`-style attribute.
  fn elem(name : String, attr : String?) -> Unit raise @xml.XmlError {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, name))
    match attr {
      Some(v) => w.attribute(@xml.QName::unqualified("dir"), v)
      None => ()
    }
    w.end_element()
  }

  match kind {
    NoEffect => ()
    Blinds(o) => elem("blinds", Some(o.to_xml()))
    Checker(o) => elem("checker", Some(o.to_xml()))
    Circle => elem("circle", None)
    Comb(o) => elem("comb", Some(o.to_xml()))
    Cover(d) => elem("cover", Some(d.to_xml()))
    Cut(thru_black) => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "cut"))
      if thru_black {
        w.attribute(@xml.QName::unqualified("thruBlk"), "1")
      }
      w.end_element()
    }
    Diamond => elem("diamond", None)
    Dissolve => elem("dissolve", None)
    Fade(thru_black) => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "fade"))
      if thru_black {
        w.attribute(@xml.QName::unqualified("thruBlk"), "1")
      }
      w.end_element()
    }
    Newsflash => elem("newsflash", None)
    Plus => elem("plus", None)
    Pull(d) => elem("pull", Some(d.to_xml()))
    Push(s) => elem("push", Some(s.to_xml()))
    Random => elem("random", None)
    RandomBar(o) => elem("randomBar", Some(o.to_xml()))
    Split(orient, dir) => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "split"))
      w.attribute(@xml.QName::unqualified("orient"), orient.to_xml())
      w.attribute(@xml.QName::unqualified("dir"), dir.to_xml())
      w.end_element()
    }
    Strips(c) => elem("strips", Some(c.to_xml()))
    Wedge => elem("wedge", None)
    Wheel(spokes) => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "wheel"))
      // Emit `spokes` only when it differs from the schema default.
      if spokes != transition_default_spokes {
        w.attribute(@xml.QName::unqualified("spokes"), spokes.to_string())
      }
      w.end_element()
    }
    Wipe(s) => elem("wipe", Some(s.to_xml()))
    Zoom(d) => elem("zoom", Some(d.to_xml()))
  }
}

///|
/// Serialise a `Slide` back to `slideN.xml`-shaped bytes.
pub fn Slide::serialize(self : Slide) -> FixedArray[Byte] raise SlideError {
  let xml = write_slide_xml(self, "sld") catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
/// Serialise with a non-default root local name — `<p:notes>` for
/// speaker-notes parts. Same content model as `<p:sld>`; the only
/// difference is the root element's local name.
pub fn Slide::serialize_with_root(
  self : Slide,
  root_local_name : String,
) -> FixedArray[Byte] raise SlideError {
  let xml = write_slide_xml(self, root_local_name) catch {
    e => raise wrap_xml(e)
  }
  @oxml.string_to_bytes(xml)
}

///|
fn write_slide_xml(
  s : Slide,
  root_local_name : String,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, root_local_name))
  w.namespace_attr("p", @oxml.presentation_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  // <p:cSld>
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cSld"))
  if s.name != "" {
    w.attribute(@xml.QName::unqualified("name"), s.name)
  }
  // <p:bg> first per CT_CommonSlideData ordering (roadmap A7).
  match s.background {
    Some(bg) => write_bg(w, ctx, bg)
    None => ()
  }
  // cSld-level captured extensions (controls).
  for ext in s.extension {
    if classify_ext(ext) is ExtCSld {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  // <p:spTree>
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "spTree"))
  // spTree-level captured extensions (nvGrpSpPr, grpSpPr) emit first
  // — they describe the implicit root group's metadata. ECMA-376
  // §19.3.1.45 marks both elements as required (`minOccurs="1"`) so
  // we synthesise a minimal pair when the source didn't carry one
  // (the typical case for hand-built notes slides or anything
  // constructed without going through a parse cycle first).
  let mut emitted_sptree_ext = false
  for ext in s.extension {
    if classify_ext(ext) is ExtSpTree {
      @oxml.write_xml_element(w, ctx, ext)
      emitted_sptree_ext = true
    }
  }
  if !emitted_sptree_ext {
    // Default wrapper matching what PowerPoint emits for a freshly-
    // created slide: cNvPr + cNvGrpSpPr + nvPr inside nvGrpSpPr, then
    // a grpSpPr carrying a zero-valued `<a:xfrm>`. The `<a:xfrm>` is
    // optional per spec but PowerPoint Online's loader normalises it
    // into existence and flags decks without it as needing repair.
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "nvGrpSpPr"))
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "cNvPr"))
    w.attribute(@xml.QName::unqualified("id"), "1")
    w.attribute(@xml.QName::unqualified("name"), "")
    w.end_element() // cNvPr
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "cNvGrpSpPr"))
    w.end_element()
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "nvPr"))
    w.end_element()
    w.end_element() // nvGrpSpPr
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "grpSpPr"))
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "xfrm"))
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "off"))
    w.attribute(@xml.QName::unqualified("x"), "0")
    w.attribute(@xml.QName::unqualified("y"), "0")
    w.end_element() // off
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "ext"))
    w.attribute(@xml.QName::unqualified("cx"), "0")
    w.attribute(@xml.QName::unqualified("cy"), "0")
    w.end_element() // ext
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "chOff"))
    w.attribute(@xml.QName::unqualified("x"), "0")
    w.attribute(@xml.QName::unqualified("y"), "0")
    w.end_element() // chOff
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "chExt"))
    w.attribute(@xml.QName::unqualified("cx"), "0")
    w.attribute(@xml.QName::unqualified("cy"), "0")
    w.end_element() // chExt
    w.end_element() // xfrm
    w.end_element() // grpSpPr
  }
  // Shapes in source order.
  for shape in s.shapes {
    write_shape(w, ctx, shape)
  }
  w.end_element() // spTree
  w.end_element() // cSld
  // <p:clrMapOvr> — shared writer in @slide_master.
  @slide_master.write_clr_map_override(w, s.clr_map_override)
  // <p:transition> after <p:clrMapOvr>, before <p:timing>, per CT_Slide
  // ordering (roadmap D3). Lifted out of `extension`, so the sld-level replay
  // below no longer carries it.
  match s.transition {
    Some(t) => write_transition(w, ctx, t)
    None => ()
  }
  // sld-level extensions (timing / custDataLst / extLst / foreign-namespace).
  for ext in s.extension {
    if classify_ext(ext) is ExtSld {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element() // sld / notes
  w.to_string()
}
