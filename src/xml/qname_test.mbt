///|
test "QName equality ignores prefix" {
  // The prefix isn't part of QName at all — same uri+local always equal.
  let a1 = @xml.QName::new("http://example.org/ns", "rect")
  let a2 = @xml.QName::new("http://example.org/ns", "rect")
  assert_eq(a1, a2)
}

///|
test "QName distinguishes uri and local name" {
  let a = @xml.QName::new("http://x", "name")
  let b = @xml.QName::new("http://y", "name")
  let c = @xml.QName::new("http://x", "other")
  assert_true(a != b)
  assert_true(a != c)
}

///|
test "unqualified vs qualified" {
  let q = @xml.QName::new("http://x", "n")
  let u = @xml.QName::unqualified("n")
  assert_true(q.is_qualified())
  assert_true(!u.is_qualified())
  assert_true(q != u)
}
