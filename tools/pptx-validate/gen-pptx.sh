#!/usr/bin/env bash
# Generate the validation corpus of .pptx files into a target directory.
#
# Today this is the in-repo showcase deck (examples/sample-deck), which
# exercises every typed feature in one file, so a clean validator run over it
# proves the library's own output opens without a PowerPoint repair prompt.
#
# The deck's committed `moon.work` makes in-repo builds resolve the
# `t-ujiie-g/moon-pptx` dependency to the repo source instead of the published
# version its `moon.mod` names — so this always validates the current tree,
# never the last release, with no manifest editing.
#
# Usage:  tools/pptx-validate/gen-pptx.sh [OUT_DIR]   (default: out)
set -euo pipefail

out_dir="${1:-out}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sample_deck="$repo_root/examples/sample-deck"
mkdir -p "$out_dir"

# The sample-deck prints the deck bytes as a single hex line; `xxd -r -p`
# decodes it to binary. `tail -1` drops any `moon` status lines printed first.
moon -C "$sample_deck" run main --target native \
  | tail -1 \
  | xxd -r -p \
  > "$out_dir/sample.pptx"

echo "wrote $out_dir/sample.pptx ($(wc -c < "$out_dir/sample.pptx") bytes)"
