// PptxGenJS side of the cross-library benchmark.
//
// Same workload as `tools/bench/moonbit` and `bench_pptx.py`: N slides,
// one text box each, serialised to an in-memory buffer. Nothing touches
// the disk, so the number is the library rather than the filesystem.
//
// PptxGenJS positions in inches; the EMU values the other two use are
// 457200 = 0.5in, 8229600 = 9in, 914400 = 1in.
//
//   node bench_pptxgenjs.js <slide-count>
const PptxGenJS = require("pptxgenjs");

const POS = { x: 0.5, y: 0.5, w: 9.0, h: 1.0 };

async function buildAndSave(n) {
  const pptx = new PptxGenJS();
  for (let i = 0; i < n; i++) {
    pptx.addSlide().addText(`Slide ${i + 1}`, POS);
  }
  const buf = await pptx.write({ outputType: "nodebuffer" });
  return buf.length;
}

buildAndSave(parseInt(process.argv[2], 10)).then((n) => console.log(n));
