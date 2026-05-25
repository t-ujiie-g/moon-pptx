// <c:externalData> round-trip preservation tests.
//
// `<c:externalData r:id="…">` is the optional chartSpace-level child
// that references an embedded `.xlsx` part (the spreadsheet cache
// PowerPoint shows when the user clicks "Edit Data"). Our builders
// emit inline `<c:strLit>` / `<c:numLit>` data instead (which the
// schema permits and PowerPoint renders correctly without an xlsx),
// so we don't generate this element. But when *reading* a deck
// produced by PowerPoint, the element must round-trip verbatim so
// the reference to the xlsx part survives a parse → serialize cycle.
//
// The xlsx part itself rides through @opc.Package as an opaque part
// keyed by content type — no SpreadsheetML parsing happens. This is
// formalised in ADR-009.

///|
test "externalData: round-trips via Chart.extension" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<c:chart><c:plotArea/></c:chart>" +
    "<c:externalData r:id=\"rId1\">" +
    "<c:autoUpdate val=\"0\"/>" +
    "</c:externalData>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  // externalData isn't a typed field; it rides on Chart.extension.
  assert_eq(original.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "externalData: rId attribute survives the round-trip" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<c:chart><c:plotArea/></c:chart>" +
    "<c:externalData r:id=\"rId42\"/>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let ext = original.extension[0]
  assert_eq(ext.name.local_name, "externalData")
  // Verify the r:id attribute is captured verbatim.
  let mut found_rid = false
  for kv in ext.attributes {
    if kv.0.local_name == "id" {
      assert_eq(kv.1, "rId42")
      found_rid = true
    }
  }
  assert_true(found_rid)
}

///|
test "externalData: works alongside a typed chart" {
  // Mix externalData with a typed bar chart -- the externalData ride
  // on Chart.extension while the chart body lifts fully.
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "<c:externalData r:id=\"rId1\"/>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  assert_eq(original.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
