# pptx-validate

A tiny .NET console tool that runs Microsoft's **Open XML SDK validator**
(`OpenXmlValidator`) over `.pptx` files and fails if any non-baselined error is
found.

## Why

moon-pptx writes `.pptx` bytes in pure MoonBit with no access to a real
PowerPoint, so "will PowerPoint show a *repair* prompt?" used to be answered
only by a human opening the deck. Several past bugs (master/layout id
collisions, foreign-namespace prefix scoping, invalid chart `dLblPos`) were
caught exactly that way — late. The Open XML SDK validator runs the same family
of schema + semantic checks PowerPoint runs on open, so a clean run here is a
high-confidence, automatable proxy for **"opens without repair."**

This is **Tier 2** of the verification pyramid (TODO.md ADR-011). Tier 1 is the
in-repo MoonBit structural-integrity + round-trip tests (`src/integration/`);
Tier 3 is opening in real PowerPoint / LibreOffice / Keynote at release time.

## Run locally

Requires the .NET 8 SDK (`dotnet`).

```bash
# 1. generate the showcase deck (needs the MoonBit toolchain + xxd)
tools/pptx-validate/gen-pptx.sh out

# 2. validate it (plus anything dropped into test_fixtures/corpus/)
dotnet run --project tools/pptx-validate -- \
  out test_fixtures/corpus \
  --baseline tools/pptx-validate/baseline.txt
```

Exit code: `0` clean · `1` validation errors · `2` bad invocation.

## Files

| File | Purpose |
|---|---|
| `Program.cs` | CLI: validate files/dirs, honour a baseline, print errors |
| `pptx-validate.csproj` | net8.0 project, references `DocumentFormat.OpenXml` |
| `gen-pptx.sh` | Emit the sample-deck `.pptx` for validation |
| `baseline.txt` | Substrings of known-safe validator quirks to ignore |

## Baseline policy

`baseline.txt` lists substrings of validation-error descriptions to ignore.
Use it **only** for documented false positives (e.g. a Microsoft extension the
SDK's strong-typed model predates). A genuine error that would trigger a
PowerPoint repair must be fixed in the library, not baselined.
