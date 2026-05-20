// Tests for the shared `collect_subtree` helper.  `skip_subtree` is already
// exercised indirectly via every typed parser, so we only test the new
// capturing helper here.

///|
/// Drive `collect_subtree` against the first element inside a fixture XML
/// document. Returns the captured `XmlElement` for assertions.
fn collect_first(xml : String) -> @xml.XmlElement raise @oxml.XmlReadError {
  let r = @xml.XmlReader::new(xml)
  let ev = @oxml.next_event(r)
  match ev {
    StartElement(name, attrs) => @oxml.collect_subtree(r, name, attrs)
    _ => raise @oxml.XmlReadError("test fixture did not start with an element")
  }
}

///|
test "collect_subtree captures a single empty element" {
  let e = collect_first("<root/>")
  assert_eq(e.name.local_name, "root")
  assert_eq(e.attributes.length(), 0)
  assert_eq(e.children.length(), 0)
}

///|
test "collect_subtree preserves attributes in source order" {
  let e = collect_first("<root a=\"1\" b=\"2\" c=\"3\"/>")
  assert_eq(e.attributes.length(), 3)
  assert_eq(e.attributes[0].0.local_name, "a")
  assert_eq(e.attributes[0].1, "1")
  assert_eq(e.attributes[1].0.local_name, "b")
  assert_eq(e.attributes[2].0.local_name, "c")
}

///|
test "collect_subtree captures nested elements" {
  let xml = "<root><a><b/></a><c/></root>"
  let e = collect_first(xml)
  assert_eq(e.children.length(), 2)
  match e.children[0] {
    Element(a) => {
      assert_eq(a.name.local_name, "a")
      assert_eq(a.children.length(), 1)
      match a.children[0] {
        Element(b) => assert_eq(b.name.local_name, "b")
        _ => fail("expected <b> inside <a>")
      }
    }
    _ => fail("expected first child to be <a>")
  }
  match e.children[1] {
    Element(c) => assert_eq(c.name.local_name, "c")
    _ => fail("expected second child to be <c>")
  }
}

///|
test "collect_subtree captures text content" {
  let e = collect_first("<root>hello</root>")
  assert_eq(e.children.length(), 1)
  match e.children[0] {
    Text(s) => assert_eq(s, "hello")
    _ => fail("expected text child")
  }
}

///|
test "collect_subtree preserves namespaces on names" {
  let xml = "<root xmlns=\"http://x\" xmlns:y=\"http://y\"><y:leaf/></root>"
  let e = collect_first(xml)
  assert_eq(e.name.uri, "http://x")
  match e.children[0] {
    Element(c) => {
      assert_eq(c.name.uri, "http://y")
      assert_eq(c.name.local_name, "leaf")
    }
    _ => fail("expected element child")
  }
}

///|
test "collect_subtree handles mixed content (text + element + text)" {
  let xml = "<root>before<mid/>after</root>"
  let e = collect_first(xml)
  assert_eq(e.children.length(), 3)
  match e.children[0] {
    Text(s) => assert_eq(s, "before")
    _ => fail("first child should be text")
  }
  match e.children[1] {
    Element(m) => assert_eq(m.name.local_name, "mid")
    _ => fail("middle child should be element")
  }
  match e.children[2] {
    Text(s) => assert_eq(s, "after")
    _ => fail("last child should be text")
  }
}

///|
test "collect_subtree captures CDATA verbatim" {
  let xml = "<root><![CDATA[<not-an-element>]]></root>"
  let e = collect_first(xml)
  assert_eq(e.children.length(), 1)
  match e.children[0] {
    CData(s) => assert_eq(s, "<not-an-element>")
    _ => fail("expected CDATA child")
  }
}

///|
test "collect_subtree leaves reader positioned after the matching EndElement" {
  // After capturing <a/> the reader should next yield <b/>, then EOF.
  let r = @xml.XmlReader::new("<doc><a/><b/></doc>")
  let _outer = @oxml.next_event(r) // <doc>
  let a_ev = @oxml.next_event(r) // <a/>
  match a_ev {
    StartElement(name, attrs) => {
      let captured = @oxml.collect_subtree(r, name, attrs)
      assert_eq(captured.name.local_name, "a")
    }
    _ => fail("expected <a> start")
  }
  let b_ev = @oxml.next_event(r)
  match b_ev {
    StartElement(name, _) => assert_eq(name.local_name, "b")
    _ => fail("expected <b> after capturing <a>")
  }
}

///|
test "collect_subtree on a deeply nested subtree round-trips structure" {
  let xml =
    #|<root><a><b><c><d/></c></b></a></root>
  let e = collect_first(xml)
  // root -> a -> b -> c -> d (each with one child until the leaf)
  fn unwrap_only_child(el : @xml.XmlElement) -> @xml.XmlElement raise {
    if el.children.length() != 1 {
      fail("expected exactly one child of <" + el.name.local_name + ">")
    }
    match el.children[0] {
      Element(child) => child
      _ => fail("expected element child")
    }
  }

  let a = unwrap_only_child(e)
  let b = unwrap_only_child(a)
  let c = unwrap_only_child(b)
  let d = unwrap_only_child(c)
  assert_eq(d.name.local_name, "d")
  assert_eq(d.children.length(), 0)
}
