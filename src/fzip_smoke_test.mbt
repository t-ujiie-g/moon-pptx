///|
/// Smoke test verifying the fzip dependency is wired up and a basic
/// ZIP roundtrip works. This is the foundation everything else builds on:
/// PPTX is a ZIP container, so if this breaks nothing else can work.
test "fzip zip roundtrip" {
  let entries : Array[(String, FixedArray[Byte])] = [
    ("[Content_Types].xml", @fzip.str_to_u8("<Types/>")),
    ("ppt/presentation.xml", @fzip.str_to_u8("<presentation/>")),
  ]
  let packed = @fzip.zip_sync(entries)
  let unpacked = @fzip.unzip_sync(packed)
  assert_eq(unpacked.length(), 2)
  let names = unpacked.map(fn(e) { e.0 })
  assert_true(names.contains("[Content_Types].xml"))
  assert_true(names.contains("ppt/presentation.xml"))
  for e in unpacked {
    let text = @fzip.str_from_u8(e.1)
    if e.0 == "[Content_Types].xml" {
      assert_eq(text, "<Types/>")
    } else {
      assert_eq(text, "<presentation/>")
    }
  }
}
