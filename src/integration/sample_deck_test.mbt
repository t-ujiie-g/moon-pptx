// Sample deck — integration test against `@sample.build_sample_deck`.
//
// The build function itself lives in `src/sample/` so that the CLI
// binary in `src/cmd_sample/` can share it. This file just exercises
// the deck: it builds, opens, and validates structural properties of
// the produced `.pptx` (slide count, shape kinds, chart count, text
// content, round-trip stability).
//
// To generate an actual `.pptx` file you can open in PowerPoint /
// Keynote / LibreOffice, run:
//
//   moon run src/cmd_sample | xxd -r -p > sample.pptx

///|
test "sample deck: builds without raising" {
  let _ = @sample.build_sample_deck()
}

///|
test "sample deck: 8 slides, IDs monotonic" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let slides = prs.slides()
  assert_eq(slides.length(), 8)
  let pres = prs.presentation_part().unwrap()
  assert_eq(pres.sld_ids.length(), 8)
  for i in 0..<pres.sld_ids.length() {
    assert_eq(pres.sld_ids[i].id, 256L + i.to_int64())
  }
}

///|
test "sample deck: title slide carries styled subtitle" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let s = prs.slides()[0]
  assert_eq(s.shapes.length(), 2)
  let title_text = match s.shapes[0] {
    AutoShape(a) => a.text_body.unwrap().plain_text()
    _ => abort("expected AutoShape title")
  }
  assert_eq(title_text, "moon-pptx — feature sample deck")
}

///|
test "sample deck: shapes slide has the 3 typed PresetShape kinds" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let s = prs.slides()[1]
  // 1 heading + 3 shapes + 3 labels = 7.
  assert_eq(s.shapes.length(), 7)
  let mut rect_count = 0
  let mut ellipse_count = 0
  let mut round_count = 0
  for sh in s.shapes {
    match sh {
      AutoShape(a) =>
        match a.geometry {
          Some(Preset(p, _)) => {
            if p == @slide.PresetShape::Rect && !(a.text_body is Some(_)) {
              rect_count = rect_count + 1
            }
            if p == @slide.PresetShape::Ellipse {
              ellipse_count = ellipse_count + 1
            }
            if p == @slide.PresetShape::RoundRect {
              round_count = round_count + 1
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  assert_eq(rect_count, 1)
  assert_eq(ellipse_count, 1)
  assert_eq(round_count, 1)
}

///|
test "sample deck: table slide has typed 3 × 3 table" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let s = prs.slides()[3]
  let mut found_table = false
  for sh in s.shapes {
    match sh {
      GraphicFrame(gf) =>
        match gf.content {
          TableContent(t) => {
            assert_eq(t.rows.length(), 3)
            assert_eq(t.rows[0].cells.length(), 3)
            let header_text = t.rows[0].cells[0].text_body.unwrap().plain_text()
            assert_eq(header_text, "Region")
            found_table = true
          }
          _ => ()
        }
      _ => ()
    }
  }
  assert_true(found_table)
}

///|
test "sample deck: charts surface count" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let charts = prs.charts()
  // Bar, line, pie, scatter, bubble = 5.
  assert_eq(charts.length(), 5)
}

///|
test "sample deck: bar chart has 2 series + 2 axes" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let bar = prs.charts()[0]
  match bar.chart.plot_area.plots[0] {
    BarChart(b) => {
      assert_eq(b.series.length(), 2)
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected BarChart as first chart")
  }
}

///|
test "sample deck: pie chart has single series" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let pie = prs.charts()[2]
  match pie.chart.plot_area.plots[0] {
    PieChart(p) => assert_eq(p.series.length(), 1)
    _ => fail("expected PieChart at index 2")
  }
}

///|
test "sample deck: scatter + bubble charts wire up correctly" {
  let bytes = @sample.build_sample_deck()
  let prs = @presentation.Presentation::open(bytes)
  let charts = prs.charts()
  match charts[3].chart.plot_area.plots[0] {
    ScatterChart(s) => assert_eq(s.series.length(), 1)
    _ => fail("expected ScatterChart at index 3")
  }
  match charts[4].chart.plot_area.plots[0] {
    BubbleChart(b) => assert_eq(b.series.length(), 1)
    _ => fail("expected BubbleChart at index 4")
  }
}

///|
test "sample deck: open → save → open is structurally stable" {
  let bytes1 = @sample.build_sample_deck()
  let prs1 = @presentation.Presentation::open(bytes1)
  let bytes2 = prs1.save()
  let prs2 = @presentation.Presentation::open(bytes2)
  assert_eq(prs2.slides().length(), 8)
  assert_eq(prs2.charts().length(), 5)
}
