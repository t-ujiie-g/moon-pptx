///|
let a_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
let p_uri : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
test "single empty element self-closes" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.end_element()
  assert_eq(w.to_string(), "<foo/>")
}

///|
test "element with text" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.text("hello")
  w.end_element()
  assert_eq(w.to_string(), "<foo>hello</foo>")
}

///|
test "element with attribute" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.attribute(@xml.QName::unqualified("id"), "42")
  w.end_element()
  assert_eq(w.to_string(), "<foo id=\"42\"/>")
}

///|
test "nested elements" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("a"))
  w.start_element(@xml.QName::unqualified("b"))
  w.text("x")
  w.end_element()
  w.end_element()
  assert_eq(w.to_string(), "<a><b>x</b></a>")
}

///|
test "namespace prefix lookup" {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("a", a_uri)
  w.start_element(@xml.QName::new(a_uri, "rect"))
  w.namespace_attr("a", a_uri)
  w.attribute(@xml.QName::unqualified("id"), "1")
  w.end_element()
  let expected = "<a:rect xmlns:a=\"" + a_uri + "\" id=\"1\"/>"
  assert_eq(w.to_string(), expected)
}

///|
test "attribute escaping" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.attribute(@xml.QName::unqualified("v"), "a&b<c>d\"e\nf")
  w.end_element()
  assert_eq(w.to_string(), "<foo v=\"a&amp;b&lt;c&gt;d&quot;e&#10;f\"/>")
}

///|
test "text escaping" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.text("if a < b && c > 0")
  w.end_element()
  assert_eq(w.to_string(), "<foo>if a &lt; b &amp;&amp; c &gt; 0</foo>")
}

///|
test "CDATA section" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.cdata("raw <stuff> & things")
  w.end_element()
  assert_eq(w.to_string(), "<foo><![CDATA[raw <stuff> & things]]></foo>")
}

///|
test "CDATA payload with ]]> is rejected" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  try w.cdata("oops ]]> closing") catch {
    @xml.XmlError::WriterMisuse(_) => ()
    _ => fail("expected WriterMisuse")
  } noraise {
    _ => fail("expected WriterMisuse")
  }
}

///|
test "attribute outside start tag is rejected" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.text("body")
  try w.attribute(@xml.QName::unqualified("late"), "x") catch {
    @xml.XmlError::WriterMisuse(_) => ()
    _ => fail("expected WriterMisuse")
  } noraise {
    _ => fail("expected WriterMisuse")
  }
}

///|
test "to_string with unclosed elements is rejected" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  try w.to_string() catch {
    @xml.XmlError::WriterMisuse(_) => ()
    _ => fail("expected WriterMisuse")
  } noraise {
    _ => fail("expected WriterMisuse")
  }
}

///|
test "unbound prefix raises UnboundPrefix" {
  let w = @xml.XmlWriter::new()
  try w.start_element(@xml.QName::new(a_uri, "rect")) catch {
    @xml.XmlError::UnboundPrefix(_) => ()
    _ => fail("expected UnboundPrefix")
  } noraise {
    _ => fail("expected UnboundPrefix")
  }
}

///|
test "xml declaration prelude" {
  let w = @xml.XmlWriter::new()
  w.xml_declaration()
  w.start_element(@xml.QName::unqualified("doc"))
  w.end_element()
  assert_eq(
    w.to_string(),
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><doc/>",
  )
}

///|
test "ooxml-style root: presentation with namespaces" {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("p", p_uri)
  w.bind_namespace("a", a_uri)
  w.xml_declaration()
  w.start_element(@xml.QName::new(p_uri, "presentation"))
  w.namespace_attr("p", p_uri)
  w.namespace_attr("a", a_uri)
  w.start_element(@xml.QName::new(a_uri, "theme"))
  w.end_element()
  w.end_element()
  let expected = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<p:presentation xmlns:p=\"" +
    p_uri +
    "\" xmlns:a=\"" +
    a_uri +
    "\"><a:theme/></p:presentation>"
  assert_eq(w.to_string(), expected)
}
