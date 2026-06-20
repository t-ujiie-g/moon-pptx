#!/usr/bin/env bash
# Generate the validation corpus of .pptx files into a target directory.
#
# Today this is the in-repo showcase deck (examples/sample-deck), which
# exercises every typed feature in one file, so a clean validator run over it
# proves the library's own output opens without a PowerPoint repair prompt.
#
# Usage:  tools/pptx-validate/gen-pptx.sh [OUT_DIR]   (default: out)
set -euo pipefail

out_dir="${1:-out}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sample_deck="$repo_root/examples/sample-deck"
mod="$sample_deck/moon.mod.json"
mkdir -p "$out_dir"

# We want to validate the *repo source*, but the sample-deck declares a
# published-version dep (what a real consumer writes, e.g. "0.5.3"). So for the
# duration of generation only, point its dep at the repo root, then restore the
# committed manifest on exit. This decouples the validator gate from release
# timing — it always tests the current tree, never the last published release.
mod_backup="$(mktemp)"
cp "$mod" "$mod_backup"
restore_mod() {
  cp "$mod_backup" "$mod"
  rm -f "$mod_backup"
}
trap restore_mod EXIT

python3 - "$mod" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["deps"]["t-ujiie-g/moon-pptx"] = {"path": "../.."}
with open(p, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY
rm -rf "$sample_deck/.mooncakes/t-ujiie-g/moon-pptx"
moon -C "$sample_deck" update >/dev/null 2>&1 || true

# The sample-deck prints the deck bytes as a single hex line; `xxd -r -p`
# decodes it to binary. `tail -1` drops any `moon` status lines printed first.
moon -C "$sample_deck" run main --target native \
  | tail -1 \
  | xxd -r -p \
  > "$out_dir/sample.pptx"

echo "wrote $out_dir/sample.pptx ($(wc -c < "$out_dir/sample.pptx") bytes)"
