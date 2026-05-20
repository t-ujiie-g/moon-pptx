///|
test "XmlElement::new wraps fields verbatim" {
  let name = @xml.QName::new("http://x", "root")
  let attrs = [(@xml.QName::unqualified("a"), "1")]
  let children = [@xml.XmlNode::Text("hello")]
  let e = @xml.XmlElement::new(name, attrs, children)
  assert_eq(e.name, name)
  assert_eq(e.attributes.length(), 1)
  assert_eq(e.children.length(), 1)
}

///|
test "XmlElement equality is structural" {
  let q = @xml.QName::unqualified("p")
  let a = @xml.XmlElement::new(q, [], [@xml.XmlNode::Text("x")])
  let b = @xml.XmlElement::new(q, [], [@xml.XmlNode::Text("x")])
  let c = @xml.XmlElement::new(q, [], [@xml.XmlNode::Text("y")])
  assert_eq(a, b)
  assert_true(a != c)
}

///|
test "XmlNode variants are distinguishable" {
  let t = @xml.XmlNode::Text("foo")
  let c = @xml.XmlNode::CData("foo")
  assert_true(t != c)
}
