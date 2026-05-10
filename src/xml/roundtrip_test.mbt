// Round-trip tests: parse → write → parse and assert the second event
// sequence matches the first.
//
// We cannot test for byte-equal output because:
//   * Attribute serialisation chooses one quote style.
//   * Self-closing vs `</foo></foo>` vs `<foo></foo>` is a writer choice.
//   * Insignificant whitespace between elements is dropped on read.
//   * Prefix labels are lost on read (only URIs survive).
//
// Semantic round-trip (same event sequence on the second parse) is what
// callers actually depend on, so that's what we assert.

///|
fn collect_uris(events : Array[@xml.XmlEvent]) -> Array[String] {
  let seen : Map[String, Unit] = Map::new()
  let out : Array[String] = []
  for e in events {
    match e {
      StartElement(name, attrs) => {
        if name.uri.length() > 0 && !seen.contains(name.uri) {
          seen[name.uri] = ()
          out.push(name.uri)
        }
        for kv in attrs {
          if kv.0.uri.length() > 0 && !seen.contains(kv.0.uri) {
            seen[kv.0.uri] = ()
            out.push(kv.0.uri)
          }
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn replay(events : Array[@xml.XmlEvent]) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let uris = collect_uris(events)
  // Assign fresh prefixes ns0, ns1, … in first-seen order.
  let prefix_for : Map[String, String] = Map::new()
  for i, uri in uris {
    let p = "ns" + i.to_string()
    prefix_for[uri] = p
    w.bind_namespace(p, uri)
  }
  w.xml_declaration()
  let mut declared = false
  for e in events {
    match e {
      StartElement(name, attrs) => {
        w.start_element(name)
        // Emit namespace declarations once, on the first element.
        if !declared {
          for uri in uris {
            w.namespace_attr(prefix_for.get(uri).unwrap(), uri)
          }
          declared = true
        }
        for kv in attrs {
          w.attribute(kv.0, kv.1)
        }
      }
      EndElement(_) => w.end_element()
      Text(s) => w.text(s)
      CData(s) => w.cdata(s)
    }
  }
  w.to_string()
}

///|
fn events_equal(a : Array[@xml.XmlEvent], b : Array[@xml.XmlEvent]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    let eq = match (a[i], b[i]) {
      (StartElement(na, aa), StartElement(nb, ab)) =>
        if na != nb || aa.length() != ab.length() {
          false
        } else {
          let mut j = 0
          let mut ok = true
          while j < aa.length() && ok {
            if aa[j].0 != ab[j].0 || aa[j].1 != ab[j].1 {
              ok = false
            }
            j = j + 1
          }
          ok
        }
      (EndElement(na), EndElement(nb)) => na == nb
      (Text(sa), Text(sb)) => sa == sb
      (CData(sa), CData(sb)) => sa == sb
      _ => false
    }
    if !eq {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn drain_again(input : String) -> Array[@xml.XmlEvent] raise @xml.XmlError {
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
test "round trip: simple element" {
  let original = "<foo/>"
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}

///|
test "round trip: nested with text and entities" {
  let original = "<a><b>hello &amp; world</b><c id=\"1\">&lt;x&gt;</c></a>"
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}

///|
test "round trip: namespaced ooxml-like document" {
  let p_uri = "http://schemas.openxmlformats.org/presentationml/2006/main"
  let a_uri = "http://schemas.openxmlformats.org/drawingml/2006/main"
  let original = "<p:presentation xmlns:p=\"" +
    p_uri +
    "\" xmlns:a=\"" +
    a_uri +
    "\">" +
    "<a:theme><a:rect id=\"1\"/><a:rect id=\"2\"/></a:theme>" +
    "</p:presentation>"
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}

///|
test "round trip: namespaced attribute" {
  let r_uri = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  let original = "<root xmlns:r=\"" + r_uri + "\" r:id=\"rId1\"/>"
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}

///|
test "round trip: CDATA payload preserved" {
  let original = "<foo><![CDATA[a < b & c > d]]></foo>"
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}

///|
test "round trip: deep nesting" {
  // A 10-deep nesting — guards against stack/state bugs that grow with depth.
  let mut open = ""
  let mut close = ""
  let mut i = 0
  while i < 10 {
    open = open + "<n" + i.to_string() + ">"
    close = "</n" + i.to_string() + ">" + close
    i = i + 1
  }
  let original = open + "leaf" + close
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}

///|
test "round trip: many attributes preserved in order" {
  let original = "<row a=\"1\" b=\"2\" c=\"3\" d=\"4\" e=\"5\" f=\"6\" g=\"7\"/>"
  let e1 = drain_again(original)
  let s2 = replay(e1)
  let e2 = drain_again(s2)
  assert_true(events_equal(e1, e2))
}
