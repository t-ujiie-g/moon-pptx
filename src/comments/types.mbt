// Comments model.
//
// PowerPoint stores threaded review comments in two complementary parts:
//
// - `commentAuthors.xml` (one per package, content type
//   `application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml`)
//   holds the master list of who can post comments. Each author has a
//   stable integer id used by the per-slide comments to attribute each
//   message. See ECMA-376 §19.3.1.1 (`CT_CommentAuthorList`).
//
// - `commentsN.xml` (zero or one per slide, content type
//   `application/vnd.openxmlformats-officedocument.presentationml.comments+xml`)
//   holds the actual comment threads for that slide — author id, posting
//   timestamp, slide-coordinate position, and the message body. See
//   ECMA-376 §19.3.1.8 (`CT_CommentList`).
//
// Both schemas are small and self-contained — no shape tree, no theme
// resolution — so they live in a stand-alone `@comments` package rather
// than getting folded into `@slide`. The lossless-extension array is
// retained on every node per ADR-004 so future Office variants (e.g.
// modernComments, threadedComments) round-trip through writers even
// before we model them.

// --- Comment authors ---

///|
/// One author entry from `<p:cmAuthor>`. All five attributes are required
/// by the spec; `clrIdx` is a colour palette index (not a theme slot —
/// it's a per-author hue tied to the author id, conventionally used by
/// PowerPoint to colour the author's marker on the slide).
///
/// - `id` — the integer key referenced by `<p:cm authorId="…"/>`.
/// - `name` — display name, e.g. "Alice Smith".
/// - `initials` — 1–3 letter initials shown on the comment marker.
/// - `last_idx` (`lastIdx`) — highest `<p:cm idx="…"/>` value posted by this
///   author across the whole presentation. Used by PowerPoint to assign the
///   next comment's idx without scanning every comments part.
/// - `clr_idx` (`clrIdx`) — per-author colour-palette index. Not a theme slot
///   (`ST_ColorSchemeIndex`) — just an opaque integer.
pub(all) struct CommentAuthor {
  id : Int
  name : String
  initials : String
  last_idx : Int
  clr_idx : Int
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// The full author list parsed from `commentAuthors.xml`. The package
/// holds at most one such part; presentations without any review
/// comments simply omit the part entirely.
///
/// - `authors` — Authors in source order. Order is not semantically
///   meaningful — `id` is the join key — but we preserve it for round-trip
///   stability.
pub struct CommentAuthorList {
  authors : Array[CommentAuthor]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

// --- Comments ---

///|
/// Slide-space position of a comment marker, in EMU. Mirrors
/// `<p:pos x="…" y="…"/>`. Both attributes are required and use
/// `ST_PositiveCoordinate32` — non-negative EMU values up to ~27 trillion.
/// We widen to `Emu` (`Int64`) so the type unifies with every other
/// EMU-bearing field even though the spec range is narrower.
pub(all) struct CommentPos {
  x : @units.Emu
  y : @units.Emu
} derive(Eq, Debug)

///|
/// One review comment parsed from `<p:cm>` in `commentsN.xml`. The
/// position-text-extLst children appear in that fixed order per the
/// schema but we don't enforce ordering on read — out-of-spec real-world
/// files surface here, so we just collect what we find.
///
/// - `author_id` (`authorId`) — joins to `CommentAuthor.id`.
/// - `dt` — ISO 8601 timestamp string when the comment was posted. Optional
///   per the schema; older PowerPoint versions omitted it. We surface it as a
///   raw `String?` rather than a parsed `DateTime` — MoonBit core doesn't
///   ship a timezone-aware datetime yet, and downstream consumers can parse
///   on demand.
/// - `idx` — per-author monotonically increasing index. Used together with
///   `authorId` as the threading key in PowerPoint's UI.
/// - `pos` (`<p:pos x y/>`) — slide-coordinate location of the comment
///   marker.
/// - `text` — `<p:text>` plain-text body. We extract the text content
///   directly; `<p:text>` does not nest any rich-text children in the schema.
pub(all) struct Comment {
  author_id : Int
  dt : String?
  idx : Int
  pos : CommentPos
  text : String
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// The full per-slide comment list parsed from `commentsN.xml`.
///
/// - `comments` — Comments in source order. Mid-thread reordering is rare but
///   we preserve whatever order the file shipped with for round-trip.
pub struct CommentList {
  comments : Array[Comment]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
