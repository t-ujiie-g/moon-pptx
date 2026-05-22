// Effect-list writer — Phase 4c slice.
//
// Inverse of `parse_effect_list`. Emits `<a:effectLst>` with the
// modeled effect children in schema-canonical order: blur → fillOverlay
// (unmodelled, lives on extension) → glow → innerShadow → outerShadow
// → presetShadow → reflection → softEdge. Captured extension elements
// (fillOverlay / extLst / foreign-namespace) emit at the end.

///|
/// Emit an `<a:effectLst>` element representing `el`.
pub fn write_effect_list(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  el : EffectList,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "effectLst"))
  match el.blur {
    Some(b) => write_blur(w, b)
    None => ()
  }
  match el.glow {
    Some(g) => write_glow(w, ctx, g)
    None => ()
  }
  match el.inner_shadow {
    Some(s) => write_inner_shadow(w, ctx, s)
    None => ()
  }
  match el.outer_shadow {
    Some(s) => write_outer_shadow(w, ctx, s)
    None => ()
  }
  match el.preset_shadow {
    Some(s) => write_preset_shadow(w, ctx, s)
    None => ()
  }
  match el.reflection {
    Some(rfl) => write_reflection(w, rfl)
    None => ()
  }
  match el.soft_edge {
    Some(se) => write_soft_edge(w, se)
    None => ()
  }
  for ext in el.extension {
    write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_blur(w : @xml.XmlWriter, b : Blur) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "blur"))
  let @units.Emu(r) = b.rad
  w.attribute(@xml.QName::unqualified("rad"), r.to_string())
  match b.grow {
    Some(g) =>
      w.attribute(@xml.QName::unqualified("grow"), if g { "1" } else { "0" })
    None => ()
  }
  w.end_element()
}

///|
fn write_glow(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  g : Glow,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "glow"))
  let @units.Emu(r) = g.rad
  w.attribute(@xml.QName::unqualified("rad"), r.to_string())
  write_color(w, ctx, g.color)
  w.end_element()
}

///|
fn write_inner_shadow(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  s : InnerShadow,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "innerShdw"))
  let @units.Emu(br) = s.blur_rad
  let @units.Emu(d) = s.dist
  w.attribute(@xml.QName::unqualified("blurRad"), br.to_string())
  w.attribute(@xml.QName::unqualified("dist"), d.to_string())
  w.attribute(@xml.QName::unqualified("dir"), s.dir.to_ooxml().to_string())
  write_color(w, ctx, s.color)
  w.end_element()
}

///|
fn write_outer_shadow(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  s : OuterShadow,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "outerShdw"))
  let @units.Emu(br) = s.blur_rad
  let @units.Emu(d) = s.dist
  w.attribute(@xml.QName::unqualified("blurRad"), br.to_string())
  w.attribute(@xml.QName::unqualified("dist"), d.to_string())
  w.attribute(@xml.QName::unqualified("dir"), s.dir.to_ooxml().to_string())
  emit_pct(w, "sx", s.sx)
  emit_pct(w, "sy", s.sy)
  emit_angle(w, "kx", s.kx)
  emit_angle(w, "ky", s.ky)
  match s.alignment {
    Some(a) =>
      w.attribute(@xml.QName::unqualified("algn"), rect_alignment_to_xml(a))
    None => ()
  }
  match s.rotate_with_shape {
    Some(b) =>
      w.attribute(
        @xml.QName::unqualified("rotWithShape"),
        if b {
          "1"
        } else {
          "0"
        },
      )
    None => ()
  }
  write_color(w, ctx, s.color)
  w.end_element()
}

///|
fn write_preset_shadow(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  s : PresetShadow,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "prstShdw"))
  w.attribute(@xml.QName::unqualified("prst"), s.preset)
  let @units.Emu(d) = s.dist
  w.attribute(@xml.QName::unqualified("dist"), d.to_string())
  w.attribute(@xml.QName::unqualified("dir"), s.dir.to_ooxml().to_string())
  write_color(w, ctx, s.color)
  w.end_element()
}

///|
fn write_soft_edge(
  w : @xml.XmlWriter,
  se : SoftEdge,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "softEdge"))
  let @units.Emu(r) = se.rad
  w.attribute(@xml.QName::unqualified("rad"), r.to_string())
  w.end_element()
}

///|
fn write_reflection(
  w : @xml.XmlWriter,
  rfl : Reflection,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "reflection"))
  match rfl.blur_rad {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("blurRad"), n.to_string())
    None => ()
  }
  emit_pct(w, "stA", rfl.st_a)
  emit_pct(w, "stPos", rfl.st_pos)
  emit_pct(w, "endA", rfl.end_a)
  emit_pct(w, "endPos", rfl.end_pos)
  match rfl.dist {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("dist"), n.to_string())
    None => ()
  }
  emit_angle(w, "dir", rfl.dir)
  emit_angle(w, "fadeDir", rfl.fade_dir)
  emit_pct(w, "sx", rfl.sx)
  emit_pct(w, "sy", rfl.sy)
  emit_angle(w, "kx", rfl.kx)
  emit_angle(w, "ky", rfl.ky)
  match rfl.alignment {
    Some(a) =>
      w.attribute(@xml.QName::unqualified("algn"), rect_alignment_to_xml(a))
    None => ()
  }
  match rfl.rotate_with_shape {
    Some(b) =>
      w.attribute(
        @xml.QName::unqualified("rotWithShape"),
        if b {
          "1"
        } else {
          "0"
        },
      )
    None => ()
  }
  w.end_element()
}

///|
fn emit_pct(
  w : @xml.XmlWriter,
  name : String,
  v : @units.Percentage?,
) -> Unit raise @xml.XmlError {
  match v {
    Some(p) =>
      w.attribute(@xml.QName::unqualified(name), p.to_ooxml().to_string())
    None => ()
  }
}

///|
fn emit_angle(
  w : @xml.XmlWriter,
  name : String,
  v : @units.Angle?,
) -> Unit raise @xml.XmlError {
  match v {
    Some(a) =>
      w.attribute(@xml.QName::unqualified(name), a.to_ooxml().to_string())
    None => ()
  }
}

///|
fn rect_alignment_to_xml(a : RectAlignment) -> String {
  match a {
    RectTopLeft => "tl"
    RectTop => "t"
    RectTopRight => "tr"
    RectLeft => "l"
    RectCenter => "ctr"
    RectRight => "r"
    RectBottomLeft => "bl"
    RectBottom => "b"
    RectBottomRight => "br"
  }
}
