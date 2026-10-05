#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DADBOD_TEST_PARSERS="${DADBOD_TEST_PARSERS:-$PWD/tests/.deps}"
"${NVIM:-nvim}" --headless -u NONE -i NONE -c 'lua dofile("tests/run.lua")'

# A separate process proves missing sql.so is safe, without mocking detection.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/parser"
cp "$DADBOD_TEST_PARSERS/parser/go.so" "$tmp/parser/"
DADBOD_TEST_PARSERS="$tmp" "${NVIM:-nvim}" --headless -u NONE -i NONE -c 'lua dofile("tests/missing-parser.lua")'

"${VIM:-vim}" -Nu NONE -i NONE -n -es -S tests/vim.vim
printf '\nPASS: Vim standalone omnifunc (no Lua/Tree-sitter required)\n'
