#!/usr/bin/env bash
# Download/build test-only parsers (ABI 14, suitable for Neovim 0.10+).
# Requires curl, tar and a C compiler. Installs nothing into your Neovim config.
set -euo pipefail
cd "$(dirname "$0")/.."
dest="${DADBOD_TEST_PARSERS:-$PWD/tests/.deps}"
mkdir -p "$dest/parser" "$dest/src"

build() {
  local language="$1" repo="$2" revision="$3"
  local source="$dest/src/$language"
  mkdir -p "$source"
  curl -fsSL "https://codeload.github.com/$repo/tar.gz/$revision" |
    tar -xz --strip-components=1 -C "$source"
  local files=("$source/src/parser.c")
  if [[ -f "$source/src/scanner.c" ]]; then files+=("$source/src/scanner.c"); fi
  "${CC:-cc}" -O2 -fPIC -shared -I"$source/src" "${files[@]}" -o "$dest/parser/$language.so"
}

build go tree-sitter/tree-sitter-go v0.23.4
build python tree-sitter/tree-sitter-python v0.23.6
build sql DerekStride/tree-sitter-sql b9d109588d5b5ed986c857464830c2f0bef53f18
printf 'Parsers installed in %s\n' "$dest"
