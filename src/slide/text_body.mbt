// Text body (`p:txBody`) skeleton — Phase 3d1 slice.
//
// Shape sketch (ECMA-376 §21.1.2.2.10):
//
//   <p:txBody>
//     <a:bodyPr …/>                <!-- 3d4 -->
//     <a:lstStyle>…</a:lstStyle>   <!-- 3d4 -->
//     <a:p>
//       <a:pPr …>…</a:pPr>         <!-- 3d3 -->
//       <a:r>
//         <a:rPr …>…</a:rPr>       <!-- 3d2 -->
//         <a:t>plain text</a:t>
//       </a:r>
//       <a:br><a:rPr …/></a:br>
//       <a:fld id="{GUID}" type="slidenum"><a:rPr/><a:t>1</a:t></a:fld>
//     </a:p>
//   </p:txBody>
//
// This commit lands just enough to extract the textual content of every
// paragraph. Run/paragraph property records are stubs that exist so later
// slices can fill them in without changing call sites.

///|
/// Underline style (`ST_TextUnderlineType`, ECMA-376 §20.1.10.81). We
/// keep only the variants real PPTX actually emits — `None`, `Words`
/// (underline excluding spaces), and the 12 line styles. Less common
/// fixed-pixel variants are mapped onto these on read; widen later if
/// real-world files surface fidelity gaps.
pub(all) enum UnderlineKind {
  UlNone // "none"
  UlWords // "words"
  UlSingle // "sng"
  UlDouble // "dbl"
  UlHeavy // "heavy"
  UlDotted // "dotted"
  UlDottedHeavy // "dottedHeavy"
  UlDash // "dash"
  UlDashHeavy // "dashHeavy"
  UlDashLong // "dashLong"
  UlDashLongHeavy // "dashLongHeavy"
  UlDotDash // "dotDash"
  UlDotDashHeavy // "dotDashHeavy"
  UlDotDotDash // "dotDotDash"
  UlDotDotDashHeavy // "dotDotDashHeavy"
  UlWavy // "wavy"
  UlWavyHeavy // "wavyHeavy"
  UlWavyDouble // "wavyDbl"
} derive(Eq, Debug)

///|
/// Strikethrough style (`ST_TextStrikeType`, §20.1.10.78).
pub(all) enum StrikeKind {
  StNoStrike // "noStrike"
  StSingle // "sngStrike"
  StDouble // "dblStrike"
} derive(Eq, Debug)

///|
/// Capitalisation style (`ST_TextCapsType`, §20.1.10.7).
pub(all) enum CapsKind {
  CapsNone // "none"
  CapsSmall // "small"
  CapsAll // "all"
} derive(Eq, Debug)

///|
/// Run-level fill. Phase 3d2 covers the two common shapes
/// (`<a:solidFill><a:srgbClr/></a:solidFill>` and
/// `<a:solidFill><a:schemeClr/></a:solidFill>`). Gradient, pattern,
/// and blip fills land alongside the shape-level fill ADT in Phase 3e.
pub(all) enum RunFill {
  SolidRgb(@units.RgbColor)
  SolidTheme(@units.ThemeColor)
} derive(Eq, Debug)

///|
/// Run property record. Every field is `Option` because OOXML rPr is
/// strictly additive over inherited values — a `None` means "inherit
/// from the next layer up" (text body default → list style → master
/// → theme). We don't synthesise defaults here; the inheritance
/// resolver does that once the surrounding layers exist.
pub(all) struct RunProperties {
  /// `xml:lang` / `lang` on the run, empty string when absent.
  lang : String
  /// `sz` — text size. OOXML stores this in 1/100 of a point; we lift
  /// to typed `Pt` at parse time.
  font_size : @units.Pt?
  /// `b` — bold.
  bold : Bool?
  /// `i` — italic.
  italic : Bool?
  /// `u` — underline style.
  underline : UnderlineKind?
  /// `strike` — strikethrough style.
  strikethrough : StrikeKind?
  /// `baseline` — vertical baseline offset in percent (negative =
  /// subscript, positive = superscript). OOXML stores as 1/1000 percent.
  baseline : @units.Percentage?
  /// `cap` — capitalisation transform.
  caps : CapsKind?
  /// `<a:latin typeface="…"/>` font for Latin script.
  latin : String?
  /// `<a:ea typeface="…"/>` font for East Asian script.
  east_asian : String?
  /// `<a:cs typeface="…"/>` font for complex script.
  complex_script : String?
  /// `<a:solidFill>` resolved to a colour.
  fill : RunFill?
  /// `<a:hlinkClick r:id="…">` — relationship id of the click target.
  hyperlink_click : String?
} derive(Eq, Debug)

///|
/// Default `RunProperties` value — every field defaults to its
/// "inherit" sentinel (`None` / empty `lang`).
pub fn RunProperties::default() -> RunProperties {
  {
    lang: "",
    font_size: None,
    bold: None,
    italic: None,
    underline: None,
    strikethrough: None,
    baseline: None,
    caps: None,
    latin: None,
    east_asian: None,
    complex_script: None,
    fill: None,
    hyperlink_click: None,
  }
}

///|
/// Parse OOXML `ST_TextUnderlineType`. Returns `None` for an
/// unrecognised value rather than raising — readers that wired up
/// `<a:rPr>` should treat unknown enums as "not present".
pub fn UnderlineKind::from_xml(s : String) -> UnderlineKind? {
  match s {
    "none" => Some(UlNone)
    "words" => Some(UlWords)
    "sng" => Some(UlSingle)
    "dbl" => Some(UlDouble)
    "heavy" => Some(UlHeavy)
    "dotted" => Some(UlDotted)
    "dottedHeavy" => Some(UlDottedHeavy)
    "dash" => Some(UlDash)
    "dashHeavy" => Some(UlDashHeavy)
    "dashLong" => Some(UlDashLong)
    "dashLongHeavy" => Some(UlDashLongHeavy)
    "dotDash" => Some(UlDotDash)
    "dotDashHeavy" => Some(UlDotDashHeavy)
    "dotDotDash" => Some(UlDotDotDash)
    "dotDotDashHeavy" => Some(UlDotDotDashHeavy)
    "wavy" => Some(UlWavy)
    "wavyHeavy" => Some(UlWavyHeavy)
    "wavyDbl" => Some(UlWavyDouble)
    _ => None
  }
}

///|
pub fn StrikeKind::from_xml(s : String) -> StrikeKind? {
  match s {
    "noStrike" => Some(StNoStrike)
    "sngStrike" => Some(StSingle)
    "dblStrike" => Some(StDouble)
    _ => None
  }
}

///|
pub fn CapsKind::from_xml(s : String) -> CapsKind? {
  match s {
    "none" => Some(CapsNone)
    "small" => Some(CapsSmall)
    "all" => Some(CapsAll)
    _ => None
  }
}

///|
/// Paragraph property record. Phase 3d1 only carries the bullet-style
/// `lvl` indentation level (default 0); 3d3 fills in alignment / bullet
/// / indent / margin fields.
pub(all) struct ParagraphProperties {
  /// Indentation level (`<a:pPr lvl="…">`); defaults to 0.
  level : Int
} derive(Eq, Debug)

///|
pub fn ParagraphProperties::default() -> ParagraphProperties {
  { level: 0 }
}

///|
/// A text run — the smallest unit of formatted text inside a paragraph.
/// Runs carry inline formatting via `RunProperties`; the actual text
/// comes from `<a:t>` children. We concatenate consecutive `<a:t>` text
/// into `text` so callers see one logical string per run.
pub(all) struct Run {
  properties : RunProperties
  text : String
} derive(Eq, Debug)

///|
/// An auto-generated field whose body text is computed at render time
/// (slide number, date, etc.). The `id` is a GUID stored verbatim;
/// `field_type` is the spec's `ST_TextFieldType` value (`slidenum`,
/// `datetime1`, `datetime2`, …, or `unknown` if absent).
pub(all) struct Field {
  id : String
  field_type : String
  properties : RunProperties
  text : String
} derive(Eq, Debug)

///|
/// One child of `<a:p>`. `<a:r>` → `Run`, `<a:br>` → `Break`,
/// `<a:fld>` → `Field`. Source order is preserved.
pub(all) enum ParagraphContent {
  RunContent(Run)
  /// Soft line break inside a paragraph. Carries the rPr of the break
  /// element (which controls the break's font metrics) for completeness.
  Break(RunProperties)
  FieldContent(Field)
} derive(Eq, Debug)

///|
/// One paragraph inside a text body.
pub(all) struct Paragraph {
  properties : ParagraphProperties
  content : Array[ParagraphContent]
} derive(Eq, Debug)

///|
/// Convenience: concatenate every run/field text inside a paragraph,
/// inserting `\n` for each `<a:br>`. Skips formatting entirely.
pub fn Paragraph::plain_text(self : Paragraph) -> String {
  let buf = StringBuilder::new(size_hint=64)
  for item in self.content {
    match item {
      RunContent(r) => buf.write_string(r.text)
      Break(_) => buf.write_char('\n')
      FieldContent(f) => buf.write_string(f.text)
    }
  }
  buf.to_string()
}

///|
/// Parsed `<p:txBody>`.
///
/// Phase 3d1 covers only the paragraph list. The (optional)
/// `<a:bodyPr>` and `<a:lstStyle>` siblings are parsed and discarded
/// for now; full handling lands in 3d4.
pub(all) struct TextBody {
  paragraphs : Array[Paragraph]
} derive(Eq, Debug)

///|
/// Plain-text concatenation across every paragraph, joining paragraphs
/// with `\n`. Useful for quick `text_body.plain_text().contains("…")`
/// queries without inspecting the typed tree.
pub fn TextBody::plain_text(self : TextBody) -> String {
  let buf = StringBuilder::new(size_hint=128)
  for i, p in self.paragraphs {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(p.plain_text())
  }
  buf.to_string()
}
