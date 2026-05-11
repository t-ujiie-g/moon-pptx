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
/// Run property record. Phase 3d1 only carries the `lang` attribute
/// (the most universally-present field on `<a:rPr>`); 3d2 fills in bold
/// / italic / underline / size / colour / font / hyperlink fields.
pub(all) struct RunProperties {
  /// xml:lang on the run, empty string when absent.
  lang : String
} derive(Eq, Debug)

///|
/// Empty default — used for runs / breaks whose `<a:rPr>` is absent or
/// carries no fields we model yet.
pub fn RunProperties::default() -> RunProperties {
  { lang: "" }
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
