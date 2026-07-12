// Structural-integrity checks over an assembled OPC package — the
// *OPC-level* class of "PowerPoint repair" triggers, caught in pure MoonBit on
// every backend.
//
// This is **Tier 1** of the verification pyramid (ADR-011): it does
// not need a real PowerPoint and runs in `moon test`. It is complementary to
// the external Open XML SDK validator (Tier 2, `tools/pptx-validate/`), which
// owns the deeper *schema/semantic* class. Here we check the three integrity
// invariants whose violation reliably makes PowerPoint repair a file:
//
//   1. every content part resolves to a content type (Default/Override);
//   2. every Internal relationship target points at a part that exists;
//   3. every `r:`-namespaced attribute value (r:id / r:embed / r:link /
//      r:dm / … — all relationship references) resolves to a relationship id
//      declared in that part's `.rels`.
//
// (3) is the dangling-`rId` bug that bit the multi-media slide
// (foreign-namespace prefix scoping) and the kind of reference breakage that a
// future writer change could silently reintroduce.
//
// These tests assert on the library's own **builder / save output** — that is
// what must be repair-clean. The synthetic read-path fixtures in
// `fixtures_test.mbt` are deliberately not asserted here: `build_pptx`
// documents that it does not emit per-part `.rels` (the parsers don't need
// them), so those fixtures are valid parser scaffolds but not valid OPC
// packages, and integrity-checking them would test the fixtures, not the code.

///|
/// One structural-integrity problem. `kind` is a short machine-readable tag;
/// `detail` explains it for the assertion message.
struct IntegrityIssue {
  part : String
  kind : String
  detail : String
}

///|
/// Collect every relationship-reference id (`r:`-namespaced attribute value)
/// in an XML part. Parse errors are swallowed — XML well-formedness / schema is
/// the external validator's job; here we only care about reference integrity.
fn collect_rel_refs(xml : String) -> Array[String] {
  let ids : Array[String] = []
  let reader = @xml.XmlReader::new(xml)
  let mut go = true
  while go {
    let ev = reader.next() catch {
      _ => {
        go = false
        None
      }
    }
    match ev {
      Some(@xml.StartElement(_, attrs)) =>
        for kv in attrs {
          let (qname, value) = kv
          if qname.uri == @oxml.office_relationships_ns && value != "" {
            ids.push(value)
          }
        }
      Some(_) => ()
      None => go = false
    }
  }
  ids
}

///|
/// Run the three integrity invariants over an opened package and return every
/// violation (empty array = clean).
fn integrity_issues(pkg : @opc.Package) -> Array[IntegrityIssue] {
  let issues : Array[IntegrityIssue] = []
  let ct = pkg.content_types()
  for part in pkg.parts() {
    let name = part.name
    // The `.rels` parts and `[Content_Types].xml` are package plumbing, not
    // content parts — they carry no content-type Override and own no rels.
    if name.has_suffix(".rels") || name == @opc.content_types_part_name {
      continue
    }
    // (1) content-type coverage
    if ct.resolve(name) is None {
      issues.push({
        part: name,
        kind: "no-content-type",
        detail: "no Default/Override content type resolves this part",
      })
    }
    // This part's relationships (empty if it has no `.rels`).
    let rels = pkg.relationships_for(name) catch {
      _ => @opc.Relationships::new(name)
    }
    // (2) relationship targets resolve to a part that exists
    for rel in rels.items {
      if rel.target_mode is @opc.Internal {
        let resolved = @opc.resolve_target(name, rel.target, rel.target_mode)
        if pkg.part_by_name(resolved) is None {
          issues.push({
            part: name,
            kind: "dangling-rel-target",
            detail: "relationship \{rel.id} -> \{rel.target} resolves to \{resolved}, which has no part",
          })
        }
      }
    }
    // (3) every r:-reference in the XML resolves to a declared relationship
    if name.has_suffix(".xml") {
      let text = part.text() catch { _ => "" }
      for ref_id in collect_rel_refs(text) {
        if rels.by_id(ref_id) is None {
          issues.push({
            part: name,
            kind: "dangling-rel-id",
            detail: "r:* attribute references \{ref_id}, absent from the part's .rels",
          })
        }
      }
    }
  }
  issues
}

///|
/// Render issues into a stable multi-line string so a failing `assert_eq`
/// against `""` prints exactly what broke.
fn format_issues(issues : Array[IntegrityIssue]) -> String {
  let sb = StringBuilder::new()
  for it in issues {
    sb.write_string("[\{it.kind}] \{it.part}: \{it.detail}\n")
  }
  sb.to_string()
}

// --- tests ---

///|
test "structural integrity: presentation-builder output is repair-clean" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let s = prs.slides()[0]
  let tb = @slide.AutoShape::textbox(
    2,
    "Title",
    @units.Emu(457_200L),
    @units.Emu(2_438_400L),
    @units.Emu(8_229_600L),
    @units.Emu(914_400L),
    "Integrity check",
  )
  prs.update_slide_mut(0, s.with_shape(@slide.AutoShape(tb)))
  let pkg = @opc.Package::open(prs.save())
  assert_eq(format_issues(integrity_issues(pkg)), "")
}

///|
test "structural integrity: deck with picture + chart is repair-clean" {
  // Pictures and charts add real `r:embed` / chart relationships, so this is
  // where a dangling-`rId` regression would actually show up.
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    minimal_png(),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(1_828_800L),
    @units.Emu(1_828_800L),
  )
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(data),
    @units.Emu(3_657_600L),
    @units.Emu(914_400L),
    @units.Emu(4_572_000L),
    @units.Emu(3_429_000L),
  )
  let pkg = @opc.Package::open(prs.save())
  assert_eq(format_issues(integrity_issues(pkg)), "")
}

///|
test "structural integrity: open -> save -> reopen stays repair-clean" {
  // Round-trip a built deck through save/open twice; the reopened package must
  // still satisfy every invariant (no rels/content-type drift on re-emit).
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let once = @opc.Package::open(prs.save())
  let twice = @opc.Package::open(once.to_bytes())
  assert_eq(format_issues(integrity_issues(twice)), "")
}
