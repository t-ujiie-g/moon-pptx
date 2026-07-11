// AppProperties (docProps/app.xml) tests.

///|
/// The saved `docProps/app.xml` as a string, for raw-XML assertions.
fn saved_app_xml(prs : @presentation.Presentation) -> String raise {
  let pkg = @opc.Package::open(prs.save())
  @oxml.bytes_to_string(pkg.require_part("/docProps/app.xml").bytes)
}

///|
test "app_properties: reads the template's Application, absent fields None" {
  let prs = @presentation.Presentation::new()
  let props = prs.app_properties()
  assert_eq(props.application.unwrap(), "moon-pptx")
  assert_true(props.company is None)
  assert_true(props.manager is None)
}

///|
test "set_app_properties_mut: merges without disturbing other fields" {
  let prs = @presentation.Presentation::new()
  prs.set_app_properties_mut(
    @presentation.AppProperties::new()
    .with_company("ACME 株式会社")
    .with_manager("Coyote"),
  )
  let props = prs.app_properties()
  assert_eq(props.company.unwrap(), "ACME 株式会社")
  assert_eq(props.manager.unwrap(), "Coyote")
  // Untouched fields survive the merge.
  assert_eq(props.application.unwrap(), "moon-pptx")
  let xml = saved_app_xml(prs)
  assert_true(
    xml.contains(
      "<PresentationFormat>On-screen Show (4:3)</PresentationFormat>",
    ),
  )
  assert_true(xml.contains("<Slides>0</Slides>"))
  // Emitted with the extended-properties namespace as the default —
  // bare element names, no generated prefixes.
  assert_true(
    xml.contains("<Properties xmlns=\"" + @oxml.extended_properties_ns + "\""),
  )
  assert_true(xml.contains("<Company>ACME 株式会社</Company>"))
  assert_true(!xml.contains("ext0:"))
}

///|
test "set_app_properties_mut: setting an existing field replaces it once" {
  let prs = @presentation.Presentation::new()
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_application("my-tool 1.0"),
  )
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_application("my-tool 2.0"),
  )
  assert_eq(prs.app_properties().application.unwrap(), "my-tool 2.0")
  let xml = saved_app_xml(prs)
  let first = xml.find("<Application>").unwrap()
  let rest = xml.view(start_offset=first + 1).to_owned()
  assert_true(rest.find("<Application>") is None)
}

///|
test "app properties survive save -> reopen" {
  let prs = @presentation.Presentation::new()
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_company("Initech"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.app_properties().company.unwrap(), "Initech")
}

///|
test "set_app_properties_mut: recreates a missing part with its package rel" {
  let prs = @presentation.Presentation::new()
  // Simulate a package without docProps/app.xml.
  assert_true(prs.pkg.remove_part("/docProps/app.xml"))
  prs.set_app_properties_mut(
    @presentation.AppProperties::new()
    .with_company("Globex")
    .with_app_version("16.0000"),
  )
  let props = prs.app_properties()
  assert_eq(props.company.unwrap(), "Globex")
  assert_eq(props.app_version.unwrap(), "16.0000")
  // Exactly one extended-properties relationship on the package.
  let rels = prs.pkg.relationships_for("/")
  assert_eq(rels.by_type(@opc.rt_extended_properties).length(), 1)
  // And the whole thing still opens.
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.app_properties().company.unwrap(), "Globex")
}

///|
test "with_app_properties: immutable counterpart leaves the original untouched" {
  let prs = @presentation.Presentation::new()
  let edited = prs.with_app_properties(
    @presentation.AppProperties::new().with_company("Hooli"),
  )
  assert_true(prs.app_properties().company is None)
  assert_eq(edited.app_properties().company.unwrap(), "Hooli")
}
