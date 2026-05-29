// Shared OOXML namespace URIs used across the typed read/write layers.
//
// These are *content-XML* namespaces (drawingml, presentationml, the
// OOXML-side relationships namespace used by `r:id="…"` references). The
// OPC packaging-side namespaces (`[Content_Types].xml`, `.rels`) live in
// `@opc` because they belong to the package layer, not OOXML content.

///|
/// DrawingML main namespace — `a:` prefix. Home of `a:theme`, color
/// elements (`a:srgbClr`, `a:sysClr`, …), shapes, paragraphs, runs.
pub let drawing_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
/// PresentationML namespace — `p:` prefix. Home of `p:sldMaster`,
/// `p:sldLayout`, `p:sld`, `p:presentation`, `p:clrMap`, `p:spTree`, …
pub let presentation_ns : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
/// OOXML relationships namespace — `r:` prefix. Used inside content XML
/// for `r:id="rIdN"` references. **Distinct** from the OPC packaging
/// relationships namespace (`@opc.relationships_ns`); that one is for
/// `.rels` files only.
pub let office_relationships_ns : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

///|
/// DrawingML chart namespace — `c:` prefix. Home of `c:chartSpace`,
/// `c:chart`, `c:plotArea`, `c:barChart`, `c:lineChart`, … — i.e. the
/// chart part `/ppt/charts/chartN.xml`. Distinct from `drawing_ns`
/// because chart XML is a separate schema.
pub let chart_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/chart"

///|
/// Microsoft-extended chart namespace — `cx:` prefix. Home of the
/// extended chart families introduced with Office 2016 (waterfall,
/// treemap, sunburst, histogram, boxWhisker, funnel, paretoLine,
/// regionMap, clusteredColumn) which live in *separate* chart parts
/// (`/ppt/charts/chartExN.xml`) and use a completely different
/// schema from the original `c:` charts. Distinct from `chart_ns`.
pub let chart_ex_ns : String = "http://schemas.microsoft.com/office/drawing/2014/chartex"

///|
/// Microsoft SVG namespace — `asvg:` prefix. Home of `<asvg:svgBlip>`, the
/// Office 2016+ extension that points a picture's `<a:blip>` at an embedded
/// SVG part (with the `<a:blip r:embed>` raster acting as the fallback for
/// older viewers). Lives inside an `<a:ext>` keyed by `svg_blip_ext_uri`.
pub let svg_ns : String = "http://schemas.microsoft.com/office/drawing/2016/SVG/main"

///|
/// Microsoft PowerPoint 2010 namespace — `p14:` prefix. Home of
/// `<p14:media>`, the extension that marks a picture's media part as
/// *embedded* (vs linked). Lives inside a `<p:ext>` keyed by
/// `media_ext_uri`. Used by audio / video embedding (roadmap A6).
pub let powerpoint_2010_ns : String = "http://schemas.microsoft.com/office/powerpoint/2010/main"

///|
/// The `<p:ext>` URI keying the `<p14:media>` embed extension inside a
/// media picture's `<p:nvPr><p:extLst>`. Fixed by Office.
pub let media_ext_uri : String = "{DAA4B4D4-668B-4A5B-A93E-BE16DBB66F30}"
