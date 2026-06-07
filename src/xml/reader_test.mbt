// Helper: drain a reader to an Array of events.

///|
fn drain(input : String) -> Array[@xml.XmlEvent] raise @xml.XmlError {
  let r = @xml.XmlReader::new(input)
  let out : Array[@xml.XmlEvent] = []
  while true {
    match r.next() {
      Some(e) => out.push(e)
      None => break
    }
  }
  out
}

///|
fn ev_kind(e : @xml.XmlEvent) -> String {
  match e {
    StartElement(_, _) => "S"
    EndElement(_) => "E"
    Text(_) => "T"
    CData(_) => "C"
  }
}

///|
fn kinds(events : Array[@xml.XmlEvent]) -> String {
  let buf = StringBuilder::new()
  for e in events {
    buf.write_string(ev_kind(e))
  }
  buf.to_string()
}

///|
test "single empty element" {
  let events = drain("<foo/>")
  assert_eq(events.length(), 2)
  assert_true(events[0] is StartElement(_, _))
  assert_true(events[1] is EndElement(_))
}

///|
test "element with text" {
  let events = drain("<foo>hello</foo>")
  assert_eq(kinds(events), "STE")
  match events[1] {
    Text(s) => assert_eq(s, "hello")
    _ => fail("expected Text")
  }
}

///|
test "nested elements" {
  let events = drain("<a><b>x</b><c/></a>")
  // <a> S, <b> S, "x" T, </b> E, <c/> S+E, </a> E  ⇒ 7 events
  assert_eq(kinds(events), "SSTESEE")
}

///|
test "attribute parsing and order preserved" {
  let events = drain("<foo a=\"1\" b='2' c=\"3\"/>")
  match events[0] {
    StartElement(_, attrs) => {
      assert_eq(attrs.length(), 3)
      assert_eq(attrs[0].0.local_name, "a")
      assert_eq(attrs[0].1, "1")
      assert_eq(attrs[1].0.local_name, "b")
      assert_eq(attrs[1].1, "2")
      assert_eq(attrs[2].0.local_name, "c")
      assert_eq(attrs[2].1, "3")
    }
    _ => fail("expected StartElement")
  }
}

///|
test "entity decoding in text" {
  let events = drain("<foo>a &amp; b &lt; c &gt; d &quot; e &apos; f</foo>")
  match events[1] {
    Text(s) => assert_eq(s, "a & b < c > d \" e ' f")
    _ => fail("expected Text")
  }
}

///|
test "numeric entity decoding" {
  let events = drain("<foo>A&#65;B&#x42;C</foo>")
  match events[1] {
    Text(s) => assert_eq(s, "AABBC")
    _ => fail("expected Text")
  }
}

///|
test "CDATA content emitted raw" {
  let events = drain("<foo><![CDATA[a < b & c]]></foo>")
  assert_eq(kinds(events), "SCE")
  match events[1] {
    CData(s) => assert_eq(s, "a < b & c")
    _ => fail("expected CData")
  }
}

///|
test "comment is skipped" {
  let events = drain("<foo><!-- ignore me --><bar/></foo>")
  assert_eq(kinds(events), "SSEE")
}

///|
test "xml declaration is skipped" {
  let events = drain("<?xml version=\"1.0\" encoding=\"UTF-8\"?><foo/>")
  assert_eq(kinds(events), "SE")
}

///|
test "namespace prefix resolution" {
  let xml = "<a:rect xmlns:a=\"http://x\" xmlns:b=\"http://y\"><b:fill/></a:rect>"
  let events = drain(xml)
  assert_eq(kinds(events), "SSEE")
  match events[0] {
    StartElement(name, _) => {
      assert_eq(name.uri, "http://x")
      assert_eq(name.local_name, "rect")
    }
    _ => fail("expected StartElement")
  }
  match events[1] {
    StartElement(name, _) => {
      assert_eq(name.uri, "http://y")
      assert_eq(name.local_name, "fill")
    }
    _ => fail("expected StartElement")
  }
}

///|
test "default namespace applies to elements but not unprefixed attributes" {
  let xml = "<root xmlns=\"http://x\" id=\"1\"><child/></root>"
  let events = drain(xml)
  match events[0] {
    StartElement(name, attrs) => {
      assert_eq(name.uri, "http://x")
      assert_eq(attrs.length(), 1)
      // The `id` attribute is unprefixed; it must NOT inherit the default namespace.
      assert_eq(attrs[0].0.uri, "")
      assert_eq(attrs[0].0.local_name, "id")
    }
    _ => fail("expected StartElement")
  }
  match events[1] {
    StartElement(name, _) => assert_eq(name.uri, "http://x")
    _ => fail("expected StartElement")
  }
}

///|
test "attribute with prefix is namespaced" {
  let xml = "<root xmlns:r=\"http://r\" r:id=\"42\"/>"
  let events = drain(xml)
  match events[0] {
    StartElement(_, attrs) => {
      assert_eq(attrs.length(), 1)
      assert_eq(attrs[0].0.uri, "http://r")
      assert_eq(attrs[0].0.local_name, "id")
      assert_eq(attrs[0].1, "42")
    }
    _ => fail("expected StartElement")
  }
}

///|
test "mismatched end tag raises" {
  try drain("<a></b>") catch {
    @xml.XmlError::MismatchedEndTag(_) => ()
    _ => fail("expected MismatchedEndTag")
  } noraise {
    _ => fail("expected MismatchedEndTag")
  }
}

///|
test "unbound prefix raises" {
  try drain("<a:x/>") catch {
    @xml.XmlError::UnboundPrefix(_) => ()
    _ => fail("expected UnboundPrefix")
  } noraise {
    _ => fail("expected UnboundPrefix")
  }
}

///|
test "unexpected EOF raises" {
  try drain("<a>unfinished") catch {
    @xml.XmlError::UnexpectedEof => ()
    _ => fail("expected UnexpectedEof")
  } noraise {
    _ => fail("expected UnexpectedEof")
  }
}

///|
test "empty input returns no events" {
  let events = drain("")
  assert_eq(events.length(), 0)
}

///|
test "whitespace between root and elements is ignored" {
  let events = drain("  \n  <foo/>  \n  ")
  assert_eq(kinds(events), "SE")
}

///|
test "ooxml-style snippet round-trip events" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
    " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<a:theme><a:rect id=\"1\"/></a:theme>" +
    "</p:presentation>"
  let events = drain(xml)
  assert_eq(kinds(events), "SSSEEE")
  // First event: <p:presentation>
  match events[0] {
    StartElement(name, _) => {
      assert_eq(
        name.uri,
        "http://schemas.openxmlformats.org/presentationml/2006/main",
      )
      assert_eq(name.local_name, "presentation")
    }
    _ => fail("expected StartElement")
  }
  // Second event: <a:theme>
  match events[1] {
    StartElement(name, _) => {
      assert_eq(
        name.uri,
        "http://schemas.openxmlformats.org/drawingml/2006/main",
      )
      assert_eq(name.local_name, "theme")
    }
    _ => fail("expected StartElement")
  }
  // Third event: <a:rect id="1"/>
  match events[2] {
    StartElement(name, attrs) => {
      assert_eq(name.local_name, "rect")
      assert_eq(attrs.length(), 1)
      assert_eq(attrs[0].0.local_name, "id")
      assert_eq(attrs[0].1, "1")
    }
    _ => fail("expected StartElement")
  }
}
