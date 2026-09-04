// Throughput benchmarks — `moon bench -p t-ujiie-g/moon-pptx/integration`.
// `moon test` ignores these; they only run under `moon bench`.
//
// The workload is the one `tools/bench/` drives against python-pptx and
// PptxGenJS too: N slides, one text box each. Keeping it identical is what
// makes the cross-library table mean anything.
//
// These time the three phases in-process. `tools/bench/run.sh` measures
// what a user actually waits for — process start-up included — plus peak
// RSS, which `moon bench` cannot see.
//
// Two build variants, because they do not scale the same way. The
// idiomatic one is what the README, the cookbook and every example write;
// the hoisted one calls `slides()` once instead of once per slide.

///|
/// Add a slide, then place a text box on it — the shape every example uses.
fn build_idiomatic(n : Int) -> @presentation.Presentation raise {
  let prs = @presentation.Presentation::new()
  for i in 0..<n {
    let _ = prs.add_slide_mut(0)
    prs.update_slide_mut(
      i,
      prs.slides()[i].with_shape(@slide.AutoShape(slide_title(i))),
    )
  }
  prs
}

///|
/// The same deck using `slide_at`, which parses one slide instead of all.
fn build_slide_at(n : Int) -> @presentation.Presentation raise {
  let prs = @presentation.Presentation::new()
  for i in 0..<n {
    let _ = prs.add_slide_mut(0)
    prs.update_slide_mut(
      i,
      prs.slide_at(i).with_shape(@slide.AutoShape(slide_title(i))),
    )
  }
  prs
}

///|
/// The same deck, with the one `slides()` call lifted out of the loop.
fn build_hoisted(n : Int) -> @presentation.Presentation raise {
  let prs = @presentation.Presentation::new()
  for _ in 0..<n {
    let _ = prs.add_slide_mut(0)
  }
  let all = prs.slides()
  for i in 0..<n {
    prs.update_slide_mut(i, all[i].with_shape(@slide.AutoShape(slide_title(i))))
  }
  prs
}

///|
fn slide_title(i : Int) -> @slide.AutoShape {
  @slide.AutoShape::textbox(
    id=2,
    name="Title",
    x=@units.Emu(457_200L),
    y=@units.Emu(457_200L),
    cx=@units.Emu(8_229_600L),
    cy=@units.Emu(914_400L),
    "Slide \{i + 1}",
  )
}

///|
fn deck(n : Int) -> @presentation.Presentation {
  build_hoisted(n) catch {
    _ => abort("bench fixture: build failed")
  }
}

// --- build, as every example writes it ---

///|
test "bench build 10 (idiomatic)" (it : @bench.T) {
  it.bench(() => it.keep(build_idiomatic(10) catch { _ => abort("build") }))
}

///|
test "bench build 100 (idiomatic)" (it : @bench.T) {
  it.bench(
    () => it.keep(build_idiomatic(100) catch { _ => abort("build") }),
    count=10,
  )
}

///|
test "bench build 1000 (idiomatic)" (it : @bench.T) {
  it.bench(
    () => it.keep(build_idiomatic(1000) catch { _ => abort("build") }),
    count=1,
  )
}

// --- build, with slides() lifted out of the loop ---

///|
test "bench build 10 (hoisted)" (it : @bench.T) {
  it.bench(() => it.keep(build_hoisted(10) catch { _ => abort("build") }))
}

///|
test "bench build 100 (hoisted)" (it : @bench.T) {
  it.bench(
    () => it.keep(build_hoisted(100) catch { _ => abort("build") }),
    count=10,
  )
}

///|
test "bench build 1000 (hoisted)" (it : @bench.T) {
  it.bench(
    () => it.keep(build_hoisted(1000) catch { _ => abort("build") }),
    count=3,
  )
}

// --- save ---

///|
test "bench save 10" (it : @bench.T) {
  let prs = deck(10)
  it.bench(() => it.keep(prs.save()))
}

///|
test "bench save 100" (it : @bench.T) {
  let prs = deck(100)
  it.bench(() => it.keep(prs.save()), count=20)
}

///|
test "bench save 1000" (it : @bench.T) {
  let prs = deck(1000)
  it.bench(() => it.keep(prs.save()), count=5)
}

// --- parse ---

///|
test "bench parse 10" (it : @bench.T) {
  let bytes = deck(10).save()
  it.bench(() => {
    it.keep(
      @presentation.Presentation::open(bytes) catch {
        _ => abort("parse")
      },
    )
  })
}

///|
test "bench parse 100" (it : @bench.T) {
  let bytes = deck(100).save()
  it.bench(
    () => {
      it.keep(
        @presentation.Presentation::open(bytes) catch {
          _ => abort("parse")
        },
      )
    },
    count=20,
  )
}

///|
test "bench parse 1000" (it : @bench.T) {
  let bytes = deck(1000).save()
  it.bench(
    () => {
      it.keep(
        @presentation.Presentation::open(bytes) catch {
          _ => abort("parse")
        },
      )
    },
    count=5,
  )
}

// --- where the build cost actually goes ---
//
// `update_slide_mut` and `slides()` both call `ordered_slide_parts()`,
// which re-parses `presentation.xml` — whose `<p:sldIdLst>` grows with the
// deck — and then resolves each entry through `Package::part_by_name`, a
// linear scan. These two measure whether a single call gets more expensive
// as the deck grows, which is what makes the documented build loop
// super-linear.

///|
test "bench one update_slide_mut on a 100-slide deck" (it : @bench.T) {
  let prs = deck(100)
  let s = prs.slides()[0] catch { _ => abort("fixture") }
  it.bench(
    () => it.keep(prs.update_slide_mut(0, s) catch { _ => abort("update") }),
    count=20,
  )
}

///|
test "bench one update_slide_mut on a 1000-slide deck" (it : @bench.T) {
  let prs = deck(1000)
  let s = prs.slides()[0] catch { _ => abort("fixture") }
  it.bench(
    () => it.keep(prs.update_slide_mut(0, s) catch { _ => abort("update") }),
    count=10,
  )
}

///|
test "bench build 100 (slide_at)" (it : @bench.T) {
  it.bench(
    () => it.keep(build_slide_at(100) catch { _ => abort("build") }),
    count=10,
  )
}

///|
test "bench build 1000 (slide_at)" (it : @bench.T) {
  it.bench(
    () => it.keep(build_slide_at(1000) catch { _ => abort("build") }),
    count=3,
  )
}

///|
/// How much of what is left is `add_slide_mut` rewriting `presentation.xml`
/// on every call — an O(N) serialise per added slide.
test "bench add 100 slides, nothing else" (it : @bench.T) {
  it.bench(() => it.keep(add_only(100) catch { _ => abort("add") }), count=10)
}

///|
test "bench add 1000 slides, nothing else" (it : @bench.T) {
  it.bench(() => it.keep(add_only(1000) catch { _ => abort("add") }), count=3)
}

///|
fn add_only(n : Int) -> @presentation.Presentation raise {
  let prs = @presentation.Presentation::new()
  for _ in 0..<n {
    let _ = prs.add_slide_mut(0)
  }
  prs
}
