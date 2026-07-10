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
/// `media_ext_uri`. Used by audio / video embedding.
pub let powerpoint_2010_ns : String = "http://schemas.microsoft.com/office/powerpoint/2010/main"

///|
/// The `<p:ext>` URI keying the `<p14:media>` embed extension inside a
/// media picture's `<p:nvPr><p:extLst>`. Fixed by Office.
pub let media_ext_uri : String = "{DAA4B4D4-668B-4A5B-A93E-BE16DBB66F30}"

///|
/// DrawingML diagram (SmartArt) namespace — `dgm:` prefix. Home of
/// `<dgm:dataModel>` (data part), `<dgm:layoutDef>`, `<dgm:colorsDef>`,
/// `<dgm:styleDef>`, and the `<dgm:relIds>` reference inside a SmartArt
/// `<a:graphicData>`. Numerically equal to `graphic_data_diagram_uri`.
///
pub let diagram_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/diagram"

///|
/// Microsoft diagram-drawing namespace — `dsp:` prefix. Home of the cached
/// `<dsp:drawing>` (laid-out shapes) referenced from a SmartArt data part so
/// the diagram renders without re-running the layout engine.
pub let diagram_drawing_ns : String = "http://schemas.microsoft.com/office/drawing/2008/diagram"

///|
/// The `<a:ext>` URI keying the `<dsp:dataModelExt>` extension inside a
/// SmartArt data model's `<dgm:extLst>` — points the data part at its cached
/// `<dsp:drawing>`. Fixed by Office.
pub let diagram_data_model_ext_uri : String = "{74C2E1F8-2D9B-489B-A2DD-C0C0D5F4E0E0}"

///|
/// OPC core-properties namespace — `cp:` prefix. Home of
/// `<cp:coreProperties>` and its `<cp:keywords>` / `<cp:lastModifiedBy>` /
/// `<cp:revision>` / `<cp:category>` / `<cp:contentStatus>` /
/// `<cp:lastPrinted>` / `<cp:version>` children in `docProps/core.xml`.
///
pub let core_properties_ns : String = "http://schemas.openxmlformats.org/package/2006/metadata/core-properties"

///|
/// Dublin Core element namespace — `dc:` prefix. Home of `<dc:title>` /
/// `<dc:creator>` / `<dc:subject>` / `<dc:description>` / `<dc:identifier>`
/// / `<dc:language>` in `docProps/core.xml`.
pub let dublin_core_ns : String = "http://purl.org/dc/elements/1.1/"

///|
/// Dublin Core terms namespace — `dcterms:` prefix. Home of the W3CDTF
/// date elements `<dcterms:created>` / `<dcterms:modified>` in
/// `docProps/core.xml`.
pub let dublin_core_terms_ns : String = "http://purl.org/dc/terms/"

///|
/// XML Schema instance namespace — `xsi:` prefix. Used in
/// `docProps/core.xml` only for the `xsi:type="dcterms:W3CDTF"` attribute
/// the date elements carry.
pub let xml_schema_instance_ns : String = "http://www.w3.org/2001/XMLSchema-instance"
