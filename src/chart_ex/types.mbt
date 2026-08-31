// Extended chart model — the Microsoft 2016-era chart families.
//
// `<cx:chartSpace>` (root of `/ppt/charts/chartExN.xml`) hosts the
// chart families Office added in 2016 (waterfall, treemap, sunburst,
// histogram, boxWhisker, funnel, paretoLine, regionMap,
// clusteredColumn) under a completely separate schema from the
// original `<c:chartSpace>`. The discriminator is the `layoutId`
// attribute on the `<cx:series>` element — every kind shares the
// same `<cx:series>` element name but varies its layoutId.
//
// Element hierarchy:
//
//   <cx:chartSpace>
//     <cx:chartData>      (data dimensions, opaque XmlElement here)
//     <cx:chart>          (REQUIRED — typed as `ChartExBody`)
//       <cx:title>        (optional, captured XmlElement)
//       <cx:plotArea>     (REQUIRED)
//         <cx:plotAreaRegion>  (REQUIRED — one region)
//           <cx:plotSurface>   (optional)
//           <cx:series layoutId="…">+  (one or more series)
//         <cx:axis>*      (zero or more axes; captured XmlElement)
//       <cx:legend>       (optional, captured)
//     <cx:spPr>           (optional, captured)
//     <cx:txPr>           (optional, captured)
//     <cx:externalData>   (optional, captured)
//     <cx:extLst>         (optional, captured)

///|
/// A parsed extended-chart part (`/ppt/charts/chartExN.xml`).
///
/// - `chart_data` (`<cx:chartData>`) — the data dimensions block. Captured
///   XmlElement; typed dimensions can lift in a later slice.
/// - `chart` (`<cx:chart>`) — REQUIRED chart definition body.
pub(all) struct ChartEx {
  chart_data : @xml.XmlElement?
  chart : ChartExBody
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartEx with fn output(self, logger) {
  logger.write_string("ChartEx { … }")
  let _ = self
}

///|
/// `<cx:chart>` body.
///
/// - `title` — `<cx:title>` (CT_Title). Optional. Captured XmlElement.
/// - `plot_area` (`<cx:plotArea>`) — REQUIRED.
/// - `legend` — `<cx:legend>`. Optional. Captured XmlElement.
/// - `extension` — `<cx:extLst>` plus any foreign-namespace siblings.
pub(all) struct ChartExBody {
  title : @xml.XmlElement?
  plot_area : ChartExPlotArea
  legend : @xml.XmlElement?
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartExBody with fn output(self, logger) {
  logger.write_string("ChartExBody { … }")
  let _ = self
}

///|
/// `<cx:plotArea>` — contains exactly one plot-area region plus
/// zero or more axes.
///
/// - `plot_area_region` (`<cx:plotAreaRegion>`) — REQUIRED, exactly one per
///   schema.
/// - `axes` (`<cx:axis id="…">*`) — zero or more axes. Captured XmlElement
///   until a later slice types them.
/// - `extension` — Unmodelled children.
pub(all) struct ChartExPlotArea {
  plot_area_region : ChartExPlotAreaRegion
  axes : Array[@xml.XmlElement]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartExPlotArea with fn output(self, logger) {
  logger.write_string("ChartExPlotArea { … }")
  let _ = self
}

///|
/// `<cx:plotAreaRegion>` — wraps the series and optional plot
/// surface inside the plot area.
///
/// - `plot_surface` (`<cx:plotSurface>`) — optional surface formatting hints.
///   Captured XmlElement.
/// - `series` (`<cx:series>+`) — one or more series, each tagged with its
///   `layoutId` chart kind.
/// - `extension` — Unmodelled children.
pub(all) struct ChartExPlotAreaRegion {
  plot_surface : @xml.XmlElement?
  series : Array[ChartExSeries]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartExPlotAreaRegion with fn output(self, logger) {
  logger.write_string("ChartExPlotAreaRegion { … }")
  let _ = self
}

///|
/// `<cx:series layoutId="…" formatIdx="…">` — one series in an
/// extended chart. The `layoutId` discriminates the chart kind.
///
/// - `layout_id` (`layoutId`) — chart-kind discriminator. Required by the
///   schema.
/// - `format_idx` (`formatIdx`) — series style index in the chart's format
///   pool. Optional in the schema; we surface as `Int?`.
/// - `hidden` — `hidden` flag — optional, default false. Surfaced as `Bool?`
///   to distinguish absent from present-false.
/// - `owner_idx` (`ownerIdx`) — reference into the owning combo chart series
///   pool. Optional.
/// - `body` — The captured `<cx:series>` body, including children like
///   `<cx:tx>`, `<cx:dataLabels>`, `<cx:dataPt>`, `<cx:dataId>`,
///   `<cx:layoutPr>`, etc. The full subtree is preserved verbatim; only the
///   discriminator and the wrapper attributes lift.
pub(all) struct ChartExSeries {
  layout_id : ChartExKind
  format_idx : Int?
  hidden : Bool?
  owner_idx : Int?
  body : @xml.XmlElement
} derive(Eq, Debug)

///|
pub impl Show for ChartExSeries with fn output(self, logger) {
  logger.write_string("ChartExSeries(")
  logger.write_string(self.layout_id.to_xml())
  logger.write_string(")")
}

///|
/// Layout id values that discriminate the extended chart kind. The
/// schema (ECMA-376 §21.3.2 / MS-CT_ChartLayoutId) admits a fixed
/// vocabulary; we model every spec'd value, and route anything
/// unknown into `Other(name)` so future Microsoft extensions
/// round-trip.
///
/// - `BoxWhisker` (`layoutId="boxWhisker"`) — box-and-whisker.
/// - `ClusteredColumn` (`layoutId="clusteredColumn"`) — used as the secondary
///   plot in paretoLine combinations.
/// - `Funnel` — `layoutId="funnel"`
/// - `ParetoLine` — `layoutId="paretoLine"`
/// - `RegionMap` — `layoutId="regionMap"`
/// - `Sunburst` — `layoutId="sunburst"`
/// - `Treemap` — `layoutId="treemap"`
/// - `Waterfall` — `layoutId="waterfall"`
/// - `Histogram` — `layoutId="histogram"`
/// - `Other` — Unknown / future layout id, kept verbatim for round-trip.
pub(all) enum ChartExKind {
  BoxWhisker
  ClusteredColumn
  Funnel
  ParetoLine
  RegionMap
  Sunburst
  Treemap
  Waterfall
  Histogram
  Other(String)
} derive(Eq, Debug)

///|
pub impl Show for ChartExKind with fn output(self, logger) {
  logger.write_string(self.to_xml())
}

///|
/// Parse `ChartExKind` from its OOXML attribute string. Unknown
/// values return `None`.
pub fn ChartExKind::from_xml(s : String) -> ChartExKind {
  match s {
    "boxWhisker" => BoxWhisker
    "clusteredColumn" => ClusteredColumn
    "funnel" => Funnel
    "paretoLine" => ParetoLine
    "regionMap" => RegionMap
    "sunburst" => Sunburst
    "treemap" => Treemap
    "waterfall" => Waterfall
    "histogram" => Histogram
    _ => Other(s)
  }
}

///|
/// Serialise `ChartExKind` back to the OOXML attribute string.
pub fn ChartExKind::to_xml(self : ChartExKind) -> String {
  match self {
    BoxWhisker => "boxWhisker"
    ClusteredColumn => "clusteredColumn"
    Funnel => "funnel"
    ParetoLine => "paretoLine"
    RegionMap => "regionMap"
    Sunburst => "sunburst"
    Treemap => "treemap"
    Waterfall => "waterfall"
    Histogram => "histogram"
    Other(s) => s
  }
}
