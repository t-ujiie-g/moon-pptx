// Text body (`p:txBody`) typed model.
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
/// Run property record. Every field is `Option` because OOXML rPr is
/// strictly additive over inherited values — a `None` means "inherit
/// from the next layer up" (text body default → list style → master
/// → theme). We don't synthesise defaults here; the inheritance
/// resolver does that once the surrounding layers exist.
///
/// - `lang` — `xml:lang` / `lang` on the run, empty string when absent.
/// - `font_size` (`sz`) — text size. OOXML stores this in 1/100 of a point;
///   we lift to typed `Pt` at parse time.
/// - `character_spacing` (`spc`) — character (letter) spacing / tracking.
///   OOXML stores this as `ST_TextPoint` (1/100 of a point, may be negative
///   to tighten); we lift to typed `Pt` like `font_size`.
/// - `kerning` (`kern`) — the minimum font size (in points) at which
///   character kerning is applied. `ST_TextNonNegativePoint` (1/100 of a
///   point, non-negative); lifted to `Pt` like `font_size` / `spc`.
/// - `baseline` — vertical baseline offset in percent (negative = subscript,
///   positive = superscript). OOXML stores as 1/1000 percent.
/// - `caps` (`cap`) — capitalisation transform.
/// - `latin` — `<a:latin typeface="…"/>` font for Latin script.
/// - `east_asian` — `<a:ea typeface="…"/>` font for East Asian script.
/// - `complex_script` — `<a:cs typeface="…"/>` font for complex script.
/// - `fill` — The text fill — the full shape-level `@oxml.Fill` ADT
///   (`<a:noFill>` / `<a:solidFill>` / `<a:gradFill>` / `<a:pattFill>` /
///   `<a:blipFill>`), so gradient / pattern text is typed. Only `<a:grpFill>`
///   (not modelled by `@oxml.Fill`) still rides on the run's `extension` per
///   ADR-004.
/// - `outline` (`<a:ln>`) — the text *outline* (a `CT_LineProperties`,
///   reusing the shape-level `@oxml.Stroke`). `None` = no outline.
/// - `text_effects` (`<a:effectLst>`) — text effects (glow / shadow /
///   reflection / soft- edge), reusing the shape-level `@oxml.EffectList`.
///   `None` = none.
/// - `highlight` (`<a:highlight>`) — text highlight colour (a `CT_Color`, one
///   colour child). `None` = no highlight.
/// The four `hyperlink_*` fields are one mechanism in two states.
/// A builder (`with_hyperlink` / `with_hyperlink_to_slide`) sets
/// `hyperlink_target`; `Presentation::update_slide_mut` then allocates an
/// rId in the slide's `.rels` and rewrites it into `hyperlink_click`
/// (plus `hyperlink_action` — `"ppaction://hlinksldjump"` marks an
/// internal jump, external URLs stay `None`). A parsed run arrives with
/// `hyperlink_click` already set and `hyperlink_target` `None`.
/// `hyperlink_tooltip` is independent of both so it survives resolution.
/// Direct attribute mappings: `bold`→`b`, `italic`→`i`, `underline`→`u`,
/// `strikethrough`→`strike`.
pub(all) struct RunProperties {
  lang : String
  font_size : @units.Pt?
  character_spacing : @units.Pt?
  kerning : @units.Pt?
  bold : Bool?
  italic : Bool?
  underline : UnderlineKind?
  strikethrough : StrikeKind?
  baseline : @units.Percentage?
  caps : CapsKind?
  latin : String?
  east_asian : String?
  complex_script : String?
  fill : @oxml.Fill?
  outline : @oxml.Stroke?
  text_effects : @oxml.EffectList?
  highlight : @oxml.Color?
  hyperlink_click : String?
  hyperlink_tooltip : String?
  hyperlink_action : String?
  hyperlink_target : HyperlinkTarget?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Unresolved hyperlink target carried on a `RunProperties` value
/// while it's being built. Resolved into a slide-rels relationship
/// + `hyperlink_click` rId by `Presentation::update_slide_mut`.
///
/// - `ExternalUrl` — External URL (`mailto:`, `https://`, `file://`, …).
///   Emitted with `TargetMode::External` and relationship type
///   `rt_hyperlink`.
/// - `InternalSlide` — Internal jump to slide `slide_idx` (zero-based, as in
///   `Presentation::slides()`). Emitted with `TargetMode::Internal` and
///   relationship type `rt_slide` pointing at the target slide part.
pub(all) enum HyperlinkTarget {
  ExternalUrl(String)
  InternalSlide(Int)
} derive(Eq, Debug)

///|
pub impl Show for HyperlinkTarget with fn output(self, logger) {
  match self {
    ExternalUrl(u) => {
      logger.write_string("ExternalUrl(")
      logger.write_string(u)
      logger.write_string(")")
    }
    InternalSlide(i) => {
      logger.write_string("InternalSlide(")
      logger.write_string(i.to_string())
      logger.write_string(")")
    }
  }
}

///|
/// Default `RunProperties` value — every field defaults to its
/// "inherit" sentinel (`None` / empty `lang`).
pub fn RunProperties::default() -> RunProperties {
  {
    lang: "",
    font_size: None,
    character_spacing: None,
    kerning: None,
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
    outline: None,
    text_effects: None,
    highlight: None,
    hyperlink_click: None,
    hyperlink_tooltip: None,
    hyperlink_action: None,
    hyperlink_target: None,
    extension: [],
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
/// Parse `StrikeKind` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn StrikeKind::from_xml(s : String) -> StrikeKind? {
  match s {
    "noStrike" => Some(StNoStrike)
    "sngStrike" => Some(StSingle)
    "dblStrike" => Some(StDouble)
    _ => None
  }
}

///|
/// Parse `CapsKind` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn CapsKind::from_xml(s : String) -> CapsKind? {
  match s {
    "none" => Some(CapsNone)
    "small" => Some(CapsSmall)
    "all" => Some(CapsAll)
    _ => None
  }
}

///|
/// Paragraph alignment (`ST_TextAlignType`, ECMA-376 §20.1.10.59).
pub(all) enum TextAlignment {
  AlignLeft // "l"
  AlignCenter // "ctr"
  AlignRight // "r"
  AlignJustify // "just"
  AlignJustifyLow // "justLow"
  AlignDistributed // "dist"
  AlignThaiDistributed // "thaiDist"
} derive(Eq, Debug)

///|
/// Parse `TextAlignment` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn TextAlignment::from_xml(s : String) -> TextAlignment? {
  match s {
    "l" => Some(AlignLeft)
    "ctr" => Some(AlignCenter)
    "r" => Some(AlignRight)
    "just" => Some(AlignJustify)
    "justLow" => Some(AlignJustifyLow)
    "dist" => Some(AlignDistributed)
    "thaiDist" => Some(AlignThaiDistributed)
    _ => None
  }
}

///|
/// Auto-number bullet scheme (`ST_TextAutonumberScheme`, §20.1.10.66).
/// Covers every variant in the spec.
///
/// Variants are grouped: arabic, arabic (DBNum / regional), roman upper and
/// lower, alpha upper and lower, circled numerals, then the East-Asian /
/// Hindi / Thai / Hebrew schemes that are legal but rarely emitted.
pub(all) enum AutoNumType {
  ArabicPeriod // "arabicPeriod" — "1."
  ArabicParenR // "arabicParenR" — "1)"
  ArabicParenBoth // "arabicParenBoth" — "(1)"
  ArabicPlain // "arabicPlain" — "1"
  ArabicDbPeriod // "arabicDbPeriod"
  ArabicDbPlain // "arabicDbPlain"
  RomanUcPeriod // "romanUcPeriod"
  RomanUcParenR // "romanUcParenR"
  RomanUcParenBoth // "romanUcParenBoth"
  RomanLcPeriod // "romanLcPeriod"
  RomanLcParenR // "romanLcParenR"
  RomanLcParenBoth // "romanLcParenBoth"
  AlphaUcPeriod // "alphaUcPeriod"
  AlphaUcParenR // "alphaUcParenR"
  AlphaUcParenBoth // "alphaUcParenBoth"
  AlphaLcPeriod // "alphaLcPeriod"
  AlphaLcParenR // "alphaLcParenR"
  AlphaLcParenBoth // "alphaLcParenBoth"
  CircleNumDbPlain // "circleNumDbPlain"
  CircleNumWdBlackPlain // "circleNumWdBlackPlain"
  CircleNumWdWhitePlain // "circleNumWdWhitePlain"
  Ea1ChsPlain // "ea1ChsPlain"
  Ea1ChsPeriod // "ea1ChsPeriod"
  Ea1ChtPlain // "ea1ChtPlain"
  Ea1ChtPeriod // "ea1ChtPeriod"
  Ea1JpnChsDbPeriod // "ea1JpnChsDbPeriod"
  Ea1JpnKorPlain // "ea1JpnKorPlain"
  Ea1JpnKorPeriod // "ea1JpnKorPeriod"
  Hebrew2Minus // "hebrew2Minus"
  ThaiAlphaPeriod // "thaiAlphaPeriod"
  ThaiAlphaParenR // "thaiAlphaParenR"
  ThaiAlphaParenBoth // "thaiAlphaParenBoth"
  ThaiNumPeriod // "thaiNumPeriod"
  ThaiNumParenR // "thaiNumParenR"
  ThaiNumParenBoth // "thaiNumParenBoth"
  HindiAlphaPeriod // "hindiAlphaPeriod"
  HindiNumPeriod // "hindiNumPeriod"
  HindiNumParenR // "hindiNumParenR"
  HindiAlpha1Period // "hindiAlpha1Period"
} derive(Eq, Debug)

///|
/// Parse `AutoNumType` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn AutoNumType::from_xml(s : String) -> AutoNumType? {
  match s {
    "arabicPeriod" => Some(ArabicPeriod)
    "arabicParenR" => Some(ArabicParenR)
    "arabicParenBoth" => Some(ArabicParenBoth)
    "arabicPlain" => Some(ArabicPlain)
    "arabicDbPeriod" => Some(ArabicDbPeriod)
    "arabicDbPlain" => Some(ArabicDbPlain)
    "romanUcPeriod" => Some(RomanUcPeriod)
    "romanUcParenR" => Some(RomanUcParenR)
    "romanUcParenBoth" => Some(RomanUcParenBoth)
    "romanLcPeriod" => Some(RomanLcPeriod)
    "romanLcParenR" => Some(RomanLcParenR)
    "romanLcParenBoth" => Some(RomanLcParenBoth)
    "alphaUcPeriod" => Some(AlphaUcPeriod)
    "alphaUcParenR" => Some(AlphaUcParenR)
    "alphaUcParenBoth" => Some(AlphaUcParenBoth)
    "alphaLcPeriod" => Some(AlphaLcPeriod)
    "alphaLcParenR" => Some(AlphaLcParenR)
    "alphaLcParenBoth" => Some(AlphaLcParenBoth)
    "circleNumDbPlain" => Some(CircleNumDbPlain)
    "circleNumWdBlackPlain" => Some(CircleNumWdBlackPlain)
    "circleNumWdWhitePlain" => Some(CircleNumWdWhitePlain)
    "ea1ChsPlain" => Some(Ea1ChsPlain)
    "ea1ChsPeriod" => Some(Ea1ChsPeriod)
    "ea1ChtPlain" => Some(Ea1ChtPlain)
    "ea1ChtPeriod" => Some(Ea1ChtPeriod)
    "ea1JpnChsDbPeriod" => Some(Ea1JpnChsDbPeriod)
    "ea1JpnKorPlain" => Some(Ea1JpnKorPlain)
    "ea1JpnKorPeriod" => Some(Ea1JpnKorPeriod)
    "hebrew2Minus" => Some(Hebrew2Minus)
    "thaiAlphaPeriod" => Some(ThaiAlphaPeriod)
    "thaiAlphaParenR" => Some(ThaiAlphaParenR)
    "thaiAlphaParenBoth" => Some(ThaiAlphaParenBoth)
    "thaiNumPeriod" => Some(ThaiNumPeriod)
    "thaiNumParenR" => Some(ThaiNumParenR)
    "thaiNumParenBoth" => Some(ThaiNumParenBoth)
    "hindiAlphaPeriod" => Some(HindiAlphaPeriod)
    "hindiNumPeriod" => Some(HindiNumPeriod)
    "hindiNumParenR" => Some(HindiNumParenR)
    "hindiAlpha1Period" => Some(HindiAlpha1Period)
    _ => None
  }
}

///|
/// Bullet specification for a paragraph (`<a:buNone>` / `<a:buChar>` /
/// `<a:buAutoNum>` / `<a:buBlip>`). The bullet font and colour children
/// (`<a:buFont>`, `<a:buClr>`, etc.) are not modelled here; they live on
/// the paragraph and ride along through `RunProperties` for bullet text
/// rendering when 3e adds the full bullet-style ADT.
///
/// - `Char` (`<a:buChar char="•"/>`) — the most common bullet (Office
///   defaults).
/// - `AutoNum` — `<a:buAutoNum type="arabicPeriod" startAt="1"/>`. `start_at`
///   is `1` when the attribute is absent (the spec default).
/// - `Picture` (`<a:buBlip><a:blip r:embed="rIdN"/></a:buBlip>`) — image
///   bullet. Payload is the relationship id.
pub(all) enum Bullet {
  BulNone
  Char(String)
  AutoNum(AutoNumType, Int)
  Picture(String)
} derive(Eq, Debug)

///|
/// Paragraph property record. Covers every `<a:pPr>` attribute and
/// bullet child PowerPoint emits in practice.
///
/// All fields except `level` are `Option`. `level` defaults to `0`
/// (matches OOXML's missing-attribute default for `lvl`).
///
/// - `level` — `lvl` indentation level (0-8 for normal lists).
/// - `alignment` (`algn`) — horizontal alignment.
/// - `margin_left` (`marL`) — left margin in EMU.
/// - `indent` — first-line indent in EMU; negative = hanging indent.
/// - `line_spacing` (`<a:lnSpc>`) — line height, percent or absolute points.
/// - `space_before` (`<a:spcBef>`) — extra space above the paragraph.
/// - `space_after` (`<a:spcAft>`) — extra space below the paragraph.
/// - `bullet` — Bullet specification — `None` means "inherit from list
///   style".
/// - `rtl` — right-to-left paragraph direction. `None` inherits from the list
///   style / master rather than meaning left-to-right.
pub(all) struct ParagraphProperties {
  level : Int
  alignment : TextAlignment?
  margin_left : @units.Emu?
  indent : @units.Emu?
  line_spacing : TextSpacing?
  space_before : TextSpacing?
  space_after : TextSpacing?
  bullet : Bullet?
  rtl : Bool?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// `CT_TextSpacing` — the spacing choice shared by `<a:lnSpc>` /
/// `<a:spcBef>` / `<a:spcAft>`: a percentage of the line
/// (`<a:spcPct>`, stored as 1/1000 % in XML) or absolute points
/// (`<a:spcPts>`, stored as 1/100 pt in XML).
///
/// - `Percent` (`<a:spcPct val="…"/>`) — e.g. `Percent(Percentage(120.0))` is
///   120 % line height.
/// - `Points` (`<a:spcPts val="…"/>`) — absolute spacing in points.
pub(all) enum TextSpacing {
  Percent(@units.Percentage)
  Points(@units.Pt)
} derive(Eq, Debug)

///|
/// Empty paragraph properties — every field is `None` except
/// `level` which is `0`.
pub fn ParagraphProperties::default() -> ParagraphProperties {
  {
    level: 0,
    alignment: None,
    margin_left: None,
    indent: None,
    line_spacing: None,
    space_before: None,
    space_after: None,
    bullet: None,
    rtl: None,
    extension: [],
  }
}

///|
/// A text run — the smallest unit of formatted text inside a paragraph.
/// Runs carry inline formatting via `RunProperties`; the actual text
/// comes from `<a:t>` children. We concatenate consecutive `<a:t>` text
/// into `text` so callers see one logical string per run.
///
/// - `extension` — unmodelled `<a:r>` siblings of `<a:rPr>` and `<a:t>`. The
///   spec only defines those two children, but some tools emit `<a:extLst>`
///   or foreign-namespace decorations.
pub(all) struct Run {
  properties : RunProperties
  text : String
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// An auto-generated field whose body text is computed at render time
/// (slide number, date, etc.). The `id` is a GUID stored verbatim;
/// `field_type` is the spec's `ST_TextFieldType` value (`slidenum`,
/// `datetime1`, `datetime2`, …, or `unknown` if absent).
///
pub(all) struct Field {
  id : String
  field_type : String
  properties : RunProperties
  text : String
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// One child of `<a:p>`. `<a:r>` → `Run`, `<a:br>` → `Break`,
/// `<a:fld>` → `Field`. Source order is preserved.
///
/// - `Break` — Soft line break inside a paragraph. Carries the rPr of the
///   break element (which controls the break's font metrics) for
///   completeness.
pub(all) enum ParagraphContent {
  RunContent(Run)
  Break(RunProperties)
  FieldContent(Field)
} derive(Eq, Debug)

///|
/// One paragraph inside a text body.
///
/// - `end_run_properties` (`<a:endParaRPr>`) — the character properties the
///   *next* character typed at the end of this paragraph inherits, and what
///   an empty paragraph is styled by. PowerPoint writes it on nearly every
///   paragraph it saves; `None` means the element was absent.
pub(all) struct Paragraph {
  properties : ParagraphProperties
  content : Array[ParagraphContent]
  end_run_properties : RunProperties?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Convenience: concatenate every run/field text inside a paragraph,
/// inserting `\n` for each `<a:br>`. Skips formatting entirely.
pub fn Paragraph::plain_text(self : Paragraph) -> String {
  let buf = StringBuilder(size_hint=64)
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
/// Vertical anchor inside the text frame (`ST_TextAnchoringType`,
/// ECMA-376 §20.1.10.59).
pub(all) enum Anchor {
  AnchorTop // "t"
  AnchorCenter // "ctr"
  AnchorBottom // "b"
  AnchorJustify // "just"
  AnchorDistributed // "dist"
} derive(Eq, Debug)

///|
/// Parse `Anchor` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn Anchor::from_xml(s : String) -> Anchor? {
  match s {
    "t" => Some(AnchorTop)
    "ctr" => Some(AnchorCenter)
    "b" => Some(AnchorBottom)
    "just" => Some(AnchorJustify)
    "dist" => Some(AnchorDistributed)
    _ => None
  }
}

///|
/// Text wrapping mode (`ST_TextWrappingType`, §20.1.10.85).
pub(all) enum WrapKind {
  WrapNone // "none"
  WrapSquare // "square"
} derive(Eq, Debug)

///|
/// Parse `WrapKind` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn WrapKind::from_xml(s : String) -> WrapKind? {
  match s {
    "none" => Some(WrapNone)
    "square" => Some(WrapSquare)
    _ => None
  }
}

///|
/// Text vertical-orientation (`ST_TextVerticalType`, §20.1.10.83).
pub(all) enum VerticalText {
  VertHorz // "horz"
  VertVert // "vert"
  VertVert270 // "vert270"
  VertWordArtVert // "wordArtVert"
  VertEaVert // "eaVert"
  VertMongolianVert // "mongolianVert"
  VertWordArtVertRtl // "wordArtVertRtl"
} derive(Eq, Debug)

///|
/// Parse `VerticalText` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn VerticalText::from_xml(s : String) -> VerticalText? {
  match s {
    "horz" => Some(VertHorz)
    "vert" => Some(VertVert)
    "vert270" => Some(VertVert270)
    "wordArtVert" => Some(VertWordArtVert)
    "eaVert" => Some(VertEaVert)
    "mongolianVert" => Some(VertMongolianVert)
    "wordArtVertRtl" => Some(VertWordArtVertRtl)
    _ => None
  }
}

///|
/// Auto-fit behaviour (`<a:noAutofit>` / `<a:normAutofit>` /
/// `<a:spAutoFit>`). `NormAutoFit` carries `(fontScale, lnSpcReduction)`
/// both in 1/1000 of a percent per spec.
pub(all) enum AutoFit {
  NoAutoFit
  NormAutoFit(@units.Percentage, @units.Percentage)
  SpAutoFit
} derive(Eq, Debug)

///|
/// Parsed `<a:bodyPr>` body properties for a text frame.
///
/// All fields are `Option`. `None` everywhere means "inherit / use spec
/// defaults". The 3d4 slice covers the practical surface; warp text,
/// flatTx, and rich/RTL column attributes are deferred.
///
pub(all) struct BodyProperties {
  rotation : @units.Angle?
  vertical_text : VerticalText?
  wrap : WrapKind?
  anchor : Anchor?
  left_inset : @units.Emu?
  top_inset : @units.Emu?
  right_inset : @units.Emu?
  bottom_inset : @units.Emu?
  auto_fit : AutoFit?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Empty body properties — every optional field is `None`.
pub fn BodyProperties::default() -> BodyProperties {
  {
    rotation: None,
    vertical_text: None,
    wrap: None,
    anchor: None,
    left_inset: None,
    top_inset: None,
    right_inset: None,
    bottom_inset: None,
    auto_fit: None,
    extension: [],
  }
}

///|
/// Per-level paragraph defaults from `<a:lstStyle>`.
///
/// `default_props` corresponds to `<a:defPPr>`. `level_props[i]`
/// corresponds to `<a:lvl{i+1}pPr>` for `i ∈ 0..9` — the spec defines
/// nine levels (`lvl1pPr` … `lvl9pPr`). Missing slots are `None`.
///
pub(all) struct ListStyle {
  default_props : ParagraphProperties?
  level_props : Array[ParagraphProperties?]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Construct an empty `ListStyle` with nine `None` level slots.
pub fn ListStyle::empty() -> ListStyle {
  let level_props : Array[ParagraphProperties?] = [
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  ]
  { default_props: None, level_props, extension: [], }
}

///|
/// Parsed `<p:txBody>`.
///
/// `body_properties` mirrors `<a:bodyPr>`, `list_style` mirrors
/// `<a:lstStyle>`. Both are `Option` — many real-world text bodies omit
/// one or both. `paragraphs` is the run-bearing content in source order.
///
/// - `extension` — unmodelled `<p:txBody>` children (foreign-namespace
///   decorations). The three modelled children `<a:bodyPr>`, `<a:lstStyle>`,
///   `<a:p>` are the only DrawingML children defined, but extension-aware
///   tools (Office variants, add-ins) may emit more.
pub(all) struct TextBody {
  body_properties : BodyProperties?
  list_style : ListStyle?
  paragraphs : Array[Paragraph]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Plain-text concatenation across every paragraph, joining paragraphs
/// with `\n`. Useful for quick `text_body.plain_text().contains("…")`
/// queries without inspecting the typed tree.
pub fn TextBody::plain_text(self : TextBody) -> String {
  let buf = StringBuilder(size_hint=128)
  for i, p in self.paragraphs {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(p.plain_text())
  }
  buf.to_string()
}
