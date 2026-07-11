// Embedded chart-data workbook generation.
//
// PowerPoint's "Edit Data" button opens the chart's source rows in
// Excel via a `<c:externalData r:id>` reference to an embedded
// `.xlsx` part. Our built charts render from inline `<c:strLit>` /
// `<c:numLit>` literals alone (ADR-009), so the workbook is a pure
// UX add-on: a minimal-but-valid SpreadsheetML package mirroring the
// `ChartData` layout Excel would show — categories down column A,
// one series per column from B, series names in row 1.
//
// The workbook uses inline-string cells (`t="inlineStr"`), which
// keeps the package at four parts (workbook + sheet + two .rels) —
// no sharedStrings table.

///|
/// SpreadsheetML main namespace (`<workbook>` / `<worksheet>` roots).
let spreadsheet_ml_ns : String = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

///|
/// Workbook → worksheet relationship type (xlsx-internal).
let rt_xlsx_worksheet : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"

///|
/// Content type of `/xl/workbook.xml` inside the embedded package.
let ct_xlsx_workbook_main : String = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"

///|
/// Content type of `/xl/worksheets/sheet1.xml` inside the embedded
/// package.
let ct_xlsx_worksheet : String = "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"

///|
/// Spreadsheet column letter for a 0-based index: 0 → `A`, 25 → `Z`,
/// 26 → `AA`.
fn column_letter(idx : Int) -> String {
  let mut n = idx
  let mut out = ""
  while true {
    let digit = n % 26
    out = ('A'.to_int() + digit).unsafe_to_char().to_string() + out
    n = n / 26 - 1
    if n < 0 {
      break
    }
  }
  out
}

///|
/// An inline-string cell at `column``row`.
fn write_inline_str_cell(
  w : @xml.XmlWriter,
  column : String,
  row : Int,
  text : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "c"))
  w.attribute(@xml.QName::unqualified("r"), column + row.to_string())
  w.attribute(@xml.QName::unqualified("t"), "inlineStr")
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "is"))
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "t"))
  w.text(text)
  w.end_element()
  w.end_element()
  w.end_element()
}

///|
/// A numeric cell at `column``row`.
fn write_number_cell(
  w : @xml.XmlWriter,
  column : String,
  row : Int,
  value : Double,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "c"))
  w.attribute(@xml.QName::unqualified("r"), column + row.to_string())
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "v"))
  w.text(value.to_string())
  w.end_element()
  w.end_element()
}

///|
/// `/xl/worksheets/sheet1.xml` — the chart data as a sheet: series
/// names across row 1 (from B1), categories down column A (from A2),
/// values in the matching cells.
fn worksheet_xml(data : @chart.ChartData) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("", spreadsheet_ml_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "worksheet"))
  w.default_namespace_attr(spreadsheet_ml_ns)
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "sheetData"))
  // Row 1: blank corner + one series name per column.
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "row"))
  w.attribute(@xml.QName::unqualified("r"), "1")
  for i, s in data.series {
    write_inline_str_cell(w, column_letter(i + 1), 1, s.label)
  }
  w.end_element()
  // One row per category.
  for ci, cat in data.categories {
    let row = ci + 2
    w.start_element(@xml.QName::new(spreadsheet_ml_ns, "row"))
    w.attribute(@xml.QName::unqualified("r"), row.to_string())
    write_inline_str_cell(w, "A", row, cat)
    for si, s in data.series {
      if ci < s.values.length() {
        write_number_cell(w, column_letter(si + 1), row, s.values[ci])
      }
    }
    w.end_element()
  }
  w.end_element() // sheetData
  w.end_element() // worksheet
  w.to_string()
}

///|
/// `/xl/workbook.xml` — one sheet named `Sheet1`.
fn workbook_xml() -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("", spreadsheet_ml_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "workbook"))
  w.default_namespace_attr(spreadsheet_ml_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "sheets"))
  w.start_element(@xml.QName::new(spreadsheet_ml_ns, "sheet"))
  w.attribute(@xml.QName::unqualified("name"), "Sheet1")
  w.attribute(@xml.QName::unqualified("sheetId"), "1")
  w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), "rId1")
  w.end_element()
  w.end_element()
  w.end_element()
  w.to_string()
}

///|
/// Build the complete embedded `.xlsx` bytes for `data`.
fn chart_data_xlsx(data : @chart.ChartData) -> FixedArray[Byte] raise PptxError {
  let bytes = try {
    let pkg = @opc.Package::new()
    let ct = @opc.ContentTypes::new()
      .with_default("rels", @opc.rels_content_type)
      .with_default("xml", "application/xml")
      .with_override("/xl/workbook.xml", ct_xlsx_workbook_main)
      .with_override("/xl/worksheets/sheet1.xml", ct_xlsx_worksheet)
    pkg.set_content_types(ct)
    pkg.regenerate_content_types_part()
    pkg.add_part(
      @opc.Part::new(
        "/xl/workbook.xml",
        ct_xlsx_workbook_main,
        @oxml.string_to_bytes(workbook_xml()),
      ),
    )
    pkg.add_part(
      @opc.Part::new(
        "/xl/worksheets/sheet1.xml",
        ct_xlsx_worksheet,
        @oxml.string_to_bytes(worksheet_xml(data)),
      ),
    )
    let root_rels = @opc.Relationships::new("/").with_relationship({
      id: "rId1",
      rel_type: @opc.rt_office_document,
      target: "xl/workbook.xml",
      target_mode: Internal,
    })
    pkg.add_part(
      @opc.Part::new(
        "/_rels/.rels",
        @opc.rels_content_type,
        root_rels.serialize(),
      ),
    )
    let wb_rels = @opc.Relationships::new("/xl/workbook.xml").with_relationship({
        id: "rId1",
        rel_type: rt_xlsx_worksheet,
        target: "worksheets/sheet1.xml",
        target_mode: Internal,
      },
    )
    pkg.add_part(
      @opc.Part::new(
        "/xl/_rels/workbook.xml.rels",
        @opc.rels_content_type,
        wb_rels.serialize(),
      ),
    )
    pkg.to_bytes()
  } catch {
    e => raise OpcFailure(e.to_string())
  }
  bytes
}

///|
/// The `<c:externalData r:id="…"><c:autoUpdate val="0"/></c:externalData>`
/// element pointing a chart at its embedded workbook. Rides the
/// chart's ADR-004 `extension` array, which the chartSpace writer
/// emits in exactly this element's schema slot (after `</c:chart>`).
fn external_data_element(r_id : String) -> @xml.XmlElement {
  @xml.XmlElement::new(
    @xml.QName::new(@oxml.chart_ns, "externalData"),
    [(@xml.QName::new(@oxml.office_relationships_ns, "id"), r_id)],
    [
      @xml.XmlNode::Element(
        @xml.XmlElement::new(
          @xml.QName::new(@oxml.chart_ns, "autoUpdate"),
          [(@xml.QName::unqualified("val"), "0")],
          [],
        ),
      ),
    ],
  )
}
