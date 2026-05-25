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
pub(all) struct ChartEx {
  /// `<cx:chartData>` — the data dimensions block. Captured
  /// XmlElement; typed dimensions can lift in a later slice.
  chart_data : @xml.XmlElement?
  /// `<cx:chart>` — REQUIRED chart definition body.
  chart : ChartExBody
  /// chartSpace-level unmodelled children: clrMapOvr / spPr /
  /// txPr / externalData / extLst / foreign-namespace siblings.
  /// ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartEx with fn output(self, logger) {
  logger.write_string("ChartEx { … }")
  let _ = self
}

///|
/// `<cx:chart>` body.
pub(all) struct ChartExBody {
  /// `<cx:title>` (CT_Title). Optional. Captured XmlElement.
  title : @xml.XmlElement?
  /// `<cx:plotArea>` — REQUIRED.
  plot_area : ChartExPlotArea
  /// `<cx:legend>`. Optional. Captured XmlElement.
  legend : @xml.XmlElement?
  /// `<cx:extLst>` plus any foreign-namespace siblings.
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
pub(all) struct ChartExPlotArea {
  /// `<cx:plotAreaRegion>` — REQUIRED, exactly one per schema.
  plot_area_region : ChartExPlotAreaRegion
  /// `<cx:axis id="…">*` — zero or more axes. Captured
  /// XmlElement until a later slice types them.
  axes : Array[@xml.XmlElement]
  /// Unmodelled children.
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
pub(all) struct ChartExPlotAreaRegion {
  /// `<cx:plotSurface>` — optional surface formatting hints.
  /// Captured XmlElement.
  plot_surface : @xml.XmlElement?
  /// `<cx:series>+` — one or more series, each tagged with its
  /// `layoutId` chart kind.
  series : Array[ChartExSeries]
  /// Unmodelled children.
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
pub(all) struct ChartExSeries {
  /// `layoutId` — chart-kind discriminator. Required by the schema.
  layout_id : ChartExKind
  /// `formatIdx` — series style index in the chart's format
  /// pool. Optional in the schema; we surface as `Int?`.
  format_idx : Int?
  /// `hidden` flag — optional, default false. Surfaced as `Bool?`
  /// to distinguish absent from present-false.
  hidden : Bool?
  /// `ownerIdx` — reference into the owning combo chart series
  /// pool. Optional.
  owner_idx : Int?
  /// The captured `<cx:series>` body, including children like
  /// `<cx:tx>`, `<cx:dataLabels>`, `<cx:dataPt>`, `<cx:dataId>`,
  /// `<cx:layoutPr>`, etc. The full subtree is preserved verbatim;
  /// only the discriminator and the wrapper attributes lift.
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
pub(all) enum ChartExKind {
  /// `layoutId="boxWhisker"` — box-and-whisker.
  BoxWhisker
  /// `layoutId="clusteredColumn"` — used as the secondary plot in
  /// paretoLine combinations.
  ClusteredColumn
  /// `layoutId="funnel"`
  Funnel
  /// `layoutId="paretoLine"`
  ParetoLine
  /// `layoutId="regionMap"`
  RegionMap
  /// `layoutId="sunburst"`
  Sunburst
  /// `layoutId="treemap"`
  Treemap
  /// `layoutId="waterfall"`
  Waterfall
  /// `layoutId="histogram"`
  Histogram
  /// Unknown / future layout id, kept verbatim for round-trip.
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
