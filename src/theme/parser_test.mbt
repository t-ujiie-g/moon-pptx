// Theme parser tests.
//
// Fixture is a slimmed-down version of the default Office 2019 theme,
// covering the elements we model (clrScheme, fontScheme) plus enough
// surrounding noise (fmtScheme, objectDefaults, extLst) to verify our
// skip-subtree behaviour.

///|
let drawing : String = @oxml.drawing_ns

///|
fn office_like_theme() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<a:theme xmlns:a=\"" +
    drawing +
    "\" name=\"Office Theme\">" +
    "<a:themeElements>" +
    "<a:clrScheme name=\"Office\">" +
    "<a:dk1><a:sysClr val=\"windowText\" lastClr=\"000000\"/></a:dk1>" +
    "<a:lt1><a:sysClr val=\"window\" lastClr=\"FFFFFF\"/></a:lt1>" +
    "<a:dk2><a:srgbClr val=\"44546A\"/></a:dk2>" +
    "<a:lt2><a:srgbClr val=\"E7E6E6\"/></a:lt2>" +
    "<a:accent1><a:srgbClr val=\"5B9BD5\"/></a:accent1>" +
    "<a:accent2><a:srgbClr val=\"ED7D31\"/></a:accent2>" +
    "<a:accent3><a:srgbClr val=\"A5A5A5\"/></a:accent3>" +
    "<a:accent4><a:srgbClr val=\"FFC000\"/></a:accent4>" +
    "<a:accent5><a:srgbClr val=\"4472C4\"/></a:accent5>" +
    "<a:accent6><a:srgbClr val=\"70AD47\"/></a:accent6>" +
    "<a:hlink><a:srgbClr val=\"0563C1\"/></a:hlink>" +
    "<a:folHlink><a:srgbClr val=\"954F72\"/></a:folHlink>" +
    "</a:clrScheme>" +
    "<a:fontScheme name=\"Office\">" +
    "<a:majorFont>" +
    "<a:latin typeface=\"Calibri Light\"/>" +
    "<a:ea typeface=\"\"/>" +
    "<a:cs typeface=\"\"/>" +
    "<a:font script=\"Jpan\" typeface=\"Yu Gothic Light\"/>" +
    "<a:font script=\"Hans\" typeface=\"Dengxian Light\"/>" +
    "</a:majorFont>" +
    "<a:minorFont>" +
    "<a:latin typeface=\"Calibri\"/>" +
    "<a:ea typeface=\"\"/>" +
    "<a:cs typeface=\"\"/>" +
    "</a:minorFont>" +
    "</a:fontScheme>" +
    // fmtScheme is intentionally noisy to verify skip_subtree.
    "<a:fmtScheme name=\"Office\">" +
    "<a:fillStyleLst>" +
    "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>" +
    "<a:gradFill><a:gsLst><a:gs pos=\"0\"/></a:gsLst></a:gradFill>" +
    "</a:fillStyleLst>" +
    "</a:fmtScheme>" +
    "</a:themeElements>" +
    "<a:objectDefaults/>" +
    "<a:extraClrSchemeLst/>" +
    "</a:theme>"
  // Cheap UTF-8 encoding for ASCII-only fixture.
  let bytes = FixedArray::make(xml.length(), b'\x00')
  let chars = xml.to_array()
  let mut i = 0
  while i < chars.length() {
    bytes[i] = chars[i].to_int().to_byte()
    i = i + 1
  }
  bytes
}

///|
test "parse: top-level name and slot count" {
  let theme = @theme.Theme::parse(office_like_theme())
  assert_eq(theme.name, "Office Theme")
  assert_eq(theme.color_scheme.name, "Office")
  assert_eq(theme.font_scheme.name, "Office")
}

///|
test "parse: srgbClr slots decoded as RGB" {
  let theme = @theme.Theme::parse(office_like_theme())
  let cs = theme.color_scheme
  match cs.accent1.base {
    Srgb(rgb) => {
      assert_eq(rgb.r, 0x5B)
      assert_eq(rgb.g, 0x9B)
      assert_eq(rgb.b, 0xD5)
    }
    _ => fail("expected Srgb for accent1")
  }
  match cs.accent6.base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "70AD47")
    _ => fail("expected Srgb for accent6")
  }
}

///|
test "parse: sysClr slots decoded with lastClr fallback" {
  let theme = @theme.Theme::parse(office_like_theme())
  match theme.color_scheme.dk1.base {
    Sys(s) => {
      assert_eq(s.val, "windowText")
      assert_eq(s.last_clr.unwrap().to_hex(), "000000")
    }
    _ => fail("expected Sys for dk1")
  }
  match theme.color_scheme.lt1.base {
    Sys(s) => {
      assert_eq(s.val, "window")
      assert_eq(s.last_clr.unwrap().to_hex(), "FFFFFF")
    }
    _ => fail("expected Sys for lt1")
  }
}

///|
test "parse: every named slot is populated" {
  let theme = @theme.Theme::parse(office_like_theme())
  // If any slot was missing, parse() would have raised. Just confirm we
  // don't accidentally collapse two slots into one by spot-checking that
  // dk1 != dk2 and accent1 != accent2.
  assert_true(theme.color_scheme.dk1 != theme.color_scheme.dk2)
  assert_true(theme.color_scheme.accent1 != theme.color_scheme.accent2)
  assert_true(theme.color_scheme.hlink != theme.color_scheme.fol_hlink)
}

///|
test "parse: font collection latin/ea/cs and per-script overrides" {
  let theme = @theme.Theme::parse(office_like_theme())
  assert_eq(theme.font_scheme.major_font.latin, "Calibri Light")
  assert_eq(theme.font_scheme.major_font.ea, "")
  assert_eq(theme.font_scheme.major_font.cs, "")
  assert_eq(theme.font_scheme.major_font.scripts.length(), 2)
  assert_eq(theme.font_scheme.major_font.scripts[0].script, "Jpan")
  assert_eq(theme.font_scheme.major_font.scripts[0].typeface, "Yu Gothic Light")
  assert_eq(theme.font_scheme.major_font.scripts[1].script, "Hans")
  assert_eq(theme.font_scheme.minor_font.latin, "Calibri")
  assert_eq(theme.font_scheme.minor_font.scripts.length(), 0)
}

///|
test "parse: missing clrScheme is rejected" {
  let xml = "<?xml version=\"1.0\"?><a:theme xmlns:a=\"" +
    drawing +
    "\"><a:themeElements><a:fontScheme name=\"x\"><a:majorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:majorFont><a:minorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:minorFont></a:fontScheme></a:themeElements></a:theme>"
  let bytes = ascii_bytes(xml)
  try @theme.Theme::parse(bytes) catch {
    @theme.ThemeError::MalformedTheme(_) => ()
    _ => fail("expected MalformedTheme")
  } noraise {
    _ => fail("expected MalformedTheme")
  }
}

///|
test "parse: missing slot in clrScheme is rejected" {
  // Drop `dk1` — should raise.
  let body = "<a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1>" +
    "<a:dk2><a:srgbClr val=\"000000\"/></a:dk2>" +
    "<a:lt2><a:srgbClr val=\"FFFFFF\"/></a:lt2>" +
    "<a:accent1><a:srgbClr val=\"112233\"/></a:accent1>" +
    "<a:accent2><a:srgbClr val=\"112233\"/></a:accent2>" +
    "<a:accent3><a:srgbClr val=\"112233\"/></a:accent3>" +
    "<a:accent4><a:srgbClr val=\"112233\"/></a:accent4>" +
    "<a:accent5><a:srgbClr val=\"112233\"/></a:accent5>" +
    "<a:accent6><a:srgbClr val=\"112233\"/></a:accent6>" +
    "<a:hlink><a:srgbClr val=\"112233\"/></a:hlink>" +
    "<a:folHlink><a:srgbClr val=\"112233\"/></a:folHlink>"
  let xml = "<?xml version=\"1.0\"?><a:theme xmlns:a=\"" +
    drawing +
    "\"><a:themeElements><a:clrScheme name=\"x\">" +
    body +
    "</a:clrScheme>" +
    "<a:fontScheme name=\"x\"><a:majorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:majorFont>" +
    "<a:minorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:minorFont></a:fontScheme>" +
    "</a:themeElements></a:theme>"
  try @theme.Theme::parse(ascii_bytes(xml)) catch {
    @theme.ThemeError::MalformedTheme(_) => ()
    _ => fail("expected MalformedTheme")
  } noraise {
    _ => fail("expected MalformedTheme")
  }
}

///|
test "parse: malformed XML wraps as XmlFailure" {
  let bytes = ascii_bytes("<a:theme xmlns:a=\"" + drawing + "\"><not closed>")
  try @theme.Theme::parse(bytes) catch {
    @theme.ThemeError::XmlFailure(_, _) => ()
    _ => fail("expected XmlFailure")
  } noraise {
    _ => fail("expected XmlFailure")
  }
}

///|
test "parse: unsupported color element rejected" {
  let xml = "<?xml version=\"1.0\"?><a:theme xmlns:a=\"" +
    drawing +
    "\"><a:themeElements><a:clrScheme name=\"x\">" +
    "<a:dk1><a:scrgbClr r=\"50000\" g=\"50000\" b=\"50000\"/></a:dk1>" +
    "</a:clrScheme></a:themeElements></a:theme>"
  try @theme.Theme::parse(ascii_bytes(xml)) catch {
    @theme.ThemeError::MalformedTheme(_) => ()
    _ => fail("expected MalformedTheme")
  } noraise {
    _ => fail("expected MalformedTheme")
  }
}

// --- ADR-004 lossless preservation ---

///|
test "ADR-004: theme captures fmtScheme/objectDefaults/extraClrSchemeLst" {
  let theme = @theme.Theme::parse(office_like_theme())
  // The fixture has:
  //   <a:fmtScheme> inside <a:themeElements> → folded onto Theme.extension
  //   <a:objectDefaults/>                    → captured here too
  //   <a:extraClrSchemeLst/>                 → and here
  // Total: 3 distinct unmodelled children survive.
  let names = []
  for el in theme.extension {
    names.push(el.name.local_name)
  }
  assert_true(names.contains("fmtScheme"))
  assert_true(names.contains("objectDefaults"))
  assert_true(names.contains("extraClrSchemeLst"))
  assert_eq(theme.extension.length(), 3)
}

///|
test "ADR-004: fmtScheme subtree is preserved verbatim" {
  let theme = @theme.Theme::parse(office_like_theme())
  let mut fmt_scheme : @xml.XmlElement? = None
  for el in theme.extension {
    if el.name.local_name == "fmtScheme" {
      fmt_scheme = Some(el)
    }
  }
  let fs = fmt_scheme.unwrap()
  // fmtScheme has a single <a:fillStyleLst> child.
  assert_eq(fs.attributes.length(), 1)
  assert_eq(fs.attributes[0].0.local_name, "name")
  assert_eq(fs.children.length(), 1)
  match fs.children[0] {
    Element(fl) => {
      assert_eq(fl.name.local_name, "fillStyleLst")
      // fillStyleLst has two children: solidFill + gradFill.
      assert_eq(fl.children.length(), 2)
    }
    _ => fail("expected <a:fillStyleLst> child")
  }
}

///|
test "ADR-004: foreign-namespace child of <a:theme> is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<a:theme xmlns:a=\"" +
    drawing +
    "\" xmlns:x=\"http://example.org/ext\" name=\"x\">" +
    "<a:themeElements>" +
    "<a:clrScheme name=\"x\">" +
    twelve_slots_body() +
    "</a:clrScheme>" +
    "<a:fontScheme name=\"x\">" +
    "<a:majorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:majorFont>" +
    "<a:minorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:minorFont>" +
    "</a:fontScheme>" +
    "</a:themeElements>" +
    "<x:tag flag=\"yes\"/>" +
    "</a:theme>"
  let theme = @theme.Theme::parse(ascii_bytes(xml))
  assert_eq(theme.extension.length(), 1)
  assert_eq(theme.extension[0].name.uri, "http://example.org/ext")
  assert_eq(theme.extension[0].name.local_name, "tag")
}

// --- helpers ---

///|
fn ascii_bytes(s : String) -> FixedArray[Byte] {
  let chars = s.to_array()
  let bytes = FixedArray::make(chars.length(), b'\x00')
  let mut i = 0
  while i < chars.length() {
    bytes[i] = chars[i].to_int().to_byte()
    i = i + 1
  }
  bytes
}

///|
/// Twelve-slot `<a:clrScheme>` body shared by extension-preservation
/// tests that need a syntactically-complete colour scheme but don't care
/// about the values.
fn twelve_slots_body() -> String {
  "<a:dk1><a:srgbClr val=\"000000\"/></a:dk1>" +
  "<a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1>" +
  "<a:dk2><a:srgbClr val=\"000000\"/></a:dk2>" +
  "<a:lt2><a:srgbClr val=\"FFFFFF\"/></a:lt2>" +
  "<a:accent1><a:srgbClr val=\"112233\"/></a:accent1>" +
  "<a:accent2><a:srgbClr val=\"112233\"/></a:accent2>" +
  "<a:accent3><a:srgbClr val=\"112233\"/></a:accent3>" +
  "<a:accent4><a:srgbClr val=\"112233\"/></a:accent4>" +
  "<a:accent5><a:srgbClr val=\"112233\"/></a:accent5>" +
  "<a:accent6><a:srgbClr val=\"112233\"/></a:accent6>" +
  "<a:hlink><a:srgbClr val=\"112233\"/></a:hlink>" +
  "<a:folHlink><a:srgbClr val=\"112233\"/></a:folHlink>"
}
