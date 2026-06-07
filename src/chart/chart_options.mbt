// ADT-driven chart options (roadmap v0.4 M2).
//
// `Chart::with_options(Array[ChartOption])` is an ergonomic facade over the
// chart's already-typed model: instead of hand-assembling `ChartTitle` /
// `ChartLegend` / `DLbls` and threading them through `ChartBody` / `PlotArea`,
// the caller passes a list of high-level options and `with_options` folds each
// one into the typed fields. The existing writer serialises those fields, so
// M2 adds no parser/writer code — it is pure model construction.
//
// The headline property is compile-time exhaustiveness: `apply_chart_option`
// matches every `ChartOption` and `plot_with_d_lbls` matches every `Plot`
// kind, so adding a new option or a new plot family without handling it is a
// compiler error, not a silently-dropped feature.
//
// Scope (documented like the A6/A7/C4/D3 deviations): the v1 option set covers
// chart-level styling that maps unambiguously onto the typed model — title,
// legend, data labels, data table, and the chartSpace/chart scalar toggles.
// `Trendline(series_idx, …)` and `SecondaryAxis(series_idx)` are deferred: they
// target deep per-series / per-axis nesting (and secondary-axis restructuring
// is already handled at construction time by `Chart::of_combo`). A
// number-format option is likewise deferred until it can name its target
// (value axis vs. data labels) — the typed `NumFmt` already exists for that
// future lift.

///|
/// A single high-level chart configuration directive. Consumed by
/// `Chart::with_options`; each variant maps onto one (or, for `DataLabels`,
/// every supporting plot's) typed field of the chart model.
pub(all) enum ChartOption {
  /// Set the chart title from plain text (synthesises `<c:title><c:tx><c:rich>`
  /// …). Clears any `autoTitleDeleted` flag.
  Title(String)
  /// Remove the chart title and set `<c:autoTitleDeleted val="1"/>` so the
  /// renderer does not auto-generate one.
  TitleDeleted
  /// Show the legend at the given position (`<c:legend><c:legendPos>`).
  /// Preserves any existing per-entry overrides / styling.
  Legend(LegendPos)
  /// Remove the legend entirely.
  LegendHidden
  /// Show value data labels at the given position on every plot family that
  /// supports them (surface charts have no data labels and are left untouched).
  DataLabels(DLblPos)
  /// Remove data labels from every plot.
  DataLabelsHidden
  /// Show (`true`) or hide (`false`) the data table below the plot area
  /// (`<c:plotArea><c:dTable>`).
  DataTable(Bool)
  /// Set the `<c:style>` preset index (1..48 in practice).
  Style(Int)
  /// Set `<c:roundedCorners val="…"/>` on the chart space.
  RoundedCorners(Bool)
  /// Set `<c:plotVisOnly val="…"/>` — plot only data on visible cells.
  PlotVisibleOnly(Bool)
  /// Set `<c:dispBlanksAs val="…"/>` — how blank cells render.
  DisplayBlanks(DisplayBlanksAs)
} derive(Eq, Debug)

///|
pub impl Show for ChartOption with fn output(self, logger) {
  logger.write_string("ChartOption(")
  let tag = match self {
    Title(_) => "Title"
    TitleDeleted => "TitleDeleted"
    Legend(_) => "Legend"
    LegendHidden => "LegendHidden"
    DataLabels(_) => "DataLabels"
    DataLabelsHidden => "DataLabelsHidden"
    DataTable(_) => "DataTable"
    Style(_) => "Style"
    RoundedCorners(_) => "RoundedCorners"
    PlotVisibleOnly(_) => "PlotVisibleOnly"
    DisplayBlanks(_) => "DisplayBlanks"
  }
  logger.write_string(tag)
  logger.write_string(")")
}

///|
/// Apply a list of options to a chart, left to right (later options of the
/// same kind win). Immutable (ADR-003) — returns a new `Chart`.
///
/// ```
/// let chart = Chart::of_bar(data).with_options([
///   Title("Quarterly revenue"),
///   Legend(LegendBottom),
///   DataLabels(DLblOutEnd),
/// ])
/// ```
pub fn Chart::with_options(self : Chart, options : Array[ChartOption]) -> Chart {
  let mut c = self
  for opt in options {
    c = apply_chart_option(c, opt)
  }
  c
}

///|
/// Fold one option into the typed chart model. The match is exhaustive over
/// `ChartOption`, so a newly-added option that is not handled here is a
/// compile error.
fn apply_chart_option(chart : Chart, option : ChartOption) -> Chart {
  let body = chart.chart
  match option {
    Title(text) =>
      {
        ..chart,
        chart: {
          ..body,
          title: Some(title_of_text(text)),
          auto_title_deleted: None,
        },
      }
    TitleDeleted =>
      {
        ..chart,
        chart: { ..body, title: None, auto_title_deleted: Some(true) },
      }
    Legend(pos) =>
      { ..chart, chart: { ..body, legend: Some(legend_at(body.legend, pos)) } }
    LegendHidden => { ..chart, chart: { ..body, legend: None } }
    DataLabels(pos) =>
      {
        ..chart,
        chart: {
          ..body,
          plot_area: plot_area_with_d_lbls(body.plot_area, Some(d_lbls_at(pos))),
        },
      }
    DataLabelsHidden =>
      {
        ..chart,
        chart: {
          ..body,
          plot_area: plot_area_with_d_lbls(body.plot_area, None),
        },
      }
    DataTable(show) =>
      {
        ..chart,
        chart: {
          ..body,
          plot_area: {
            ..body.plot_area,
            data_table: if show {
              Some(make_data_table())
            } else {
              None
            },
          },
        },
      }
    Style(n) => { ..chart, style: Some(n) }
    RoundedCorners(b) => { ..chart, rounded_corners: Some(b) }
    PlotVisibleOnly(b) => { ..chart, chart: { ..body, plot_vis_only: Some(b) } }
    DisplayBlanks(d) => { ..chart, chart: { ..body, disp_blanks_as: Some(d) } }
  }
}

// --- helpers -----------------------------------------------------------------

///|
/// Construct a drawing-namespace `XmlElement` (companion to the chart-namespace
/// `c_elem`), used to synthesise the rich-text body of a chart title.
fn a_elem(
  local_name : String,
  attributes : Array[(@xml.QName, String)],
  children : Array[@xml.XmlNode],
) -> @xml.XmlElement {
  @xml.XmlElement::new(
    @xml.QName::new(@oxml.drawing_ns, local_name),
    attributes,
    children,
  )
}

///|
/// Build a `ChartTitle` carrying a single-run rich-text body for `text`.
/// `<c:title>` uses CT_Tx, whose text form is `<c:rich>` (a DrawingML text
/// body) — not the `<c:v>` plain-string form that `<c:ser><c:tx>` allows.
fn title_of_text(text : String) -> ChartTitle {
  let run = a_elem("r", [], [Element(a_elem("t", [], [Text(text)]))])
  let para = a_elem("p", [], [Element(run)])
  let rich = c_elem("rich", [], [
    Element(a_elem("bodyPr", [], [])),
    Element(a_elem("lstStyle", [], [])),
    Element(para),
  ])
  let tx = c_elem("tx", [], [Element(rich)])
  {
    tx: Some(tx),
    layout: None,
    overlay: None,
    sp_pr: None,
    tx_pr: None,
    extension: [],
  }
}

///|
/// Set the legend position, preserving the rest of an existing legend (entries,
/// layout, styling) or starting a fresh legend when none is present.
fn legend_at(existing : ChartLegend?, pos : LegendPos) -> ChartLegend {
  match existing {
    Some(lg) => { ..lg, legend_pos: Some(pos) }
    None =>
      {
        legend_pos: Some(pos),
        legend_entries: [],
        layout: None,
        overlay: None,
        sp_pr: None,
        tx_pr: None,
        extension: [],
      }
  }
}

///|
/// A default data-labels body: value labels at `pos`, nothing else shown.
fn d_lbls_at(pos : DLblPos) -> DLbls {
  {
    d_lbl: [],
    num_fmt: None,
    sp_pr: None,
    tx_pr: None,
    d_lbl_pos: Some(pos),
    show_legend_key: None,
    show_val: Some(true),
    show_cat_name: None,
    show_ser_name: None,
    show_percent: None,
    show_bubble_size: None,
    separator: None,
    extension: [],
  }
}

///|
/// Set (or clear) the plot-level data labels on every plot in the plot area.
fn plot_area_with_d_lbls(pa : PlotArea, dlbls : DLbls?) -> PlotArea {
  { ..pa, plots: pa.plots.map(fn(p) { plot_with_d_lbls(p, dlbls) }) }
}

///|
/// Replace the `<c:dLbls>` of a plot. The match is exhaustive over `Plot`:
/// every family that has a `d_lbls` field gets it set; the two surface
/// families (which have no `<c:dLbls>` in the schema) are returned unchanged.
/// Adding a new plot family without handling it here is a compile error.
fn plot_with_d_lbls(plot : Plot, dlbls : DLbls?) -> Plot {
  match plot {
    AreaChart(b) => AreaChart({ ..b, d_lbls: dlbls })
    Area3DChart(b) => Area3DChart({ ..b, d_lbls: dlbls })
    LineChart(b) => LineChart({ ..b, d_lbls: dlbls })
    Line3DChart(b) => Line3DChart({ ..b, d_lbls: dlbls })
    StockChart(b) => StockChart({ ..b, d_lbls: dlbls })
    RadarChart(b) => RadarChart({ ..b, d_lbls: dlbls })
    ScatterChart(b) => ScatterChart({ ..b, d_lbls: dlbls })
    PieChart(b) => PieChart({ ..b, d_lbls: dlbls })
    Pie3DChart(b) => Pie3DChart({ ..b, d_lbls: dlbls })
    DoughnutChart(b) => DoughnutChart({ ..b, d_lbls: dlbls })
    BarChart(b) => BarChart({ ..b, d_lbls: dlbls })
    Bar3DChart(b) => Bar3DChart({ ..b, d_lbls: dlbls })
    OfPieChart(b) => OfPieChart({ ..b, d_lbls: dlbls })
    BubbleChart(b) => BubbleChart({ ..b, d_lbls: dlbls })
    // CT_SurfaceChart / CT_Surface3DChart have no <c:dLbls> child.
    SurfaceChart(_) | Surface3DChart(_) => plot
  }
}

///|
/// Synthesise a `<c:dTable>` (CT_DTable) with the conventional all-on display
/// flags PowerPoint emits when "Show Data Table" is enabled.
fn make_data_table() -> @xml.XmlElement {
  fn flag(name : String) -> @xml.XmlNode {
    Element(c_elem(name, [(@xml.QName::unqualified("val"), "1")], []))
  }

  c_elem("dTable", [], [
    flag("showHorzBorder"),
    flag("showVertBorder"),
    flag("showOutline"),
    flag("showKeys"),
  ])
}
