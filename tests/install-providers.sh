#!/usr/bin/env bash
# Optional real completion-engine pipeline tests; no fuzzy binary/UI required.
set -euo pipefail
cd "$(dirname "$0")/.."
fetch() {
  local repo="$1" ref="$2" dest="$3"
  mkdir -p "$dest"
  curl -fsSL "https://codeload.github.com/$repo/tar.gz/$ref" |
    tar -xz --strip-components=1 -C "$dest"
}
fetch hrsh7th/nvim-cmp 2ffe79f1f021def8dd1fcd81deb16f1bb0d989f3 tests/.deps/nvim-cmp
fetch Saghen/blink.cmp v1.7.0 tests/.deps/blink.cmp
