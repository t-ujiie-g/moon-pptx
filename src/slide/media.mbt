// Audio / video media on a picture shape (roadmap v0.3 A6).
//
// In OOXML an embedded media clip is a `<p:pic>` whose `<p:nvPr>` carries an
// `<a:videoFile>` / `<a:audioFile>` (`r:link` to the media part) plus a
// `<p14:media>` extension (`r:embed` to the same part), with a
// `ppaction://media` hyperlink on `<p:cNvPr>` and a poster frame in
// `<p:blipFill>`. We model that as an optional `Picture.media` rather than a
// separate shape kind, reusing the picture's poster `blip_fill` and transform.

///|
/// Whether a media picture is a video or an audio clip — selects
/// `<a:videoFile>` vs `<a:audioFile>`.
pub(all) enum MediaKind {
  Video
  Audio
} derive(Eq, Debug)

///|
/// The media references attached to a media `<p:pic>` (roadmap A6).
pub(all) struct MediaInfo {
  kind : MediaKind
  /// `r:link` on `<a:videoFile>` / `<a:audioFile>` — the media part via the
  /// `video` / `audio` relationship.
  link_id : String
  /// `r:embed` on `<p14:media>` — the same media part via the Office 2007+
  /// `media` relationship (marks the clip as embedded, not linked).
  embed_id : String
} derive(Eq, Debug)

///|
/// Construct a media `Picture` (roadmap A6). `link_id` is the `r:link` of the
/// `<a:videoFile>` / `<a:audioFile>`, `media_embed_id` the `r:embed` of the
/// `<p14:media>` extension (both pointing at the media part), and
/// `poster_embed_id` the `r:embed` of the poster-frame image in `blipFill`.
/// All relationships + parts are wired by
/// `@presentation.Presentation::add_video_mut` / `add_audio_mut`.
pub fn Picture::of_media(
  id : Int,
  name : String,
  kind : MediaKind,
  link_id : String,
  media_embed_id : String,
  poster_embed_id : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Picture {
  {
    id,
    name,
    transform: Some(Transform::new(offset={ x, y }, extent={ cx, cy })),
    geometry: Some(Preset(PresetShape::Rect, [])),
    stroke: None,
    effects: None,
    blip_fill: {
      embed_id: poster_embed_id,
      link_id: "",
      src_rect: None,
      fill_mode: Stretch(None),
      extension: [],
    },
    media: Some({ kind, link_id, embed_id: media_embed_id }),
    extension: [],
  }
}

///|
/// Build the `<p:nvPr>` media children for `m`: the `<a:videoFile>` /
/// `<a:audioFile>` link element and the `<p:extLst>` holding `<p14:media>`.
/// Returned as captured `XmlElement`s so `write_xml_element` auto-declares
/// the `p14` namespace (the slide writer doesn't bind it at the root).
fn media_nv_elements(m : MediaInfo) -> Array[@xml.XmlElement] {
  let tag = match m.kind {
    Video => "videoFile"
    Audio => "audioFile"
  }
  let media_file = @xml.XmlElement::new(
    @xml.QName::new(@oxml.drawing_ns, tag),
    [(@xml.QName::new(@oxml.office_relationships_ns, "link"), m.link_id)],
    [],
  )
  let p14_media = @xml.XmlElement::new(
    @xml.QName::new(@oxml.powerpoint_2010_ns, "media"),
    [(@xml.QName::new(@oxml.office_relationships_ns, "embed"), m.embed_id)],
    [],
  )
  let ext = @xml.XmlElement::new(
    @xml.QName::new(@oxml.presentation_ns, "ext"),
    [(@xml.QName::unqualified("uri"), @oxml.media_ext_uri)],
    [Element(p14_media)],
  )
  let ext_lst = @xml.XmlElement::new(
    @xml.QName::new(@oxml.presentation_ns, "extLst"),
    [],
    [Element(ext)],
  )
  [media_file, ext_lst]
}
