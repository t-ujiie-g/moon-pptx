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
mkdir -p "$out_dir"

# The sample-deck is a standalone module (its own moon.mod.json) that prints
# the deck bytes as a single hex line; `xxd -r -p` decodes it to binary.
# `tail -1` drops any `moon` status lines printed before the payload.
moon -C "$repo_root/examples/sample-deck" run main --target native \
  | tail -1 \
  | xxd -r -p \
  > "$out_dir/sample.pptx"

echo "wrote $out_dir/sample.pptx ($(wc -c < "$out_dir/sample.pptx") bytes)"
