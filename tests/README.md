# Headless tests

From the repository root, with Neovim 0.10+, Vim, Bash, curl, tar and a C compiler:

```sh
bash tests/install-parsers.sh
bash tests/run.sh
```

The installer downloads pinned parser sources and builds Linux-compatible shared
libraries in ignored `tests/.deps/`; it does not change your editor configuration.
The harness isolates `runtimepath` from user plugins/queries. Test-only injection
queries live in `tests/fixtures/queries/`, **not** the plugin runtime's queries
folder. No database server, Dadbod installation, or nvim-treesitter is required.

Default parser versions:

- Go: `tree-sitter/tree-sitter-go` v0.23.4
- Python: `tree-sitter/tree-sitter-python` v0.23.6
- SQL: `DerekStride/tree-sitter-sql` b9d109588d5b5ed986c857464830c2f0bef53f18

These use ABI 14, including for Neovim 0.10. The suite also passes on Neovim 0.12.2
with newer ABI 15 parsers (including Go's `statement_list` grammar layout).
To use other installed parsers or editor versions:

```sh
DADBOD_TEST_PARSERS=/path/to/runtime/containing/parser NVIM=/path/to/nvim bash tests/run.sh
```

`VIM=/path/to/vim` overrides the Vim executable. Parsers must match the selected
Neovim's supported ABI. Missing prerequisites are failures, not silently skipped.

## Actual completion-engine pipelines (optional)

The default suite invokes both Dadbod source adapters through their public
provider APIs. For additional tests through real nvim-cmp source/entry processing
and Blink provider/edit processing:

```sh
bash tests/install-providers.sh
DADBOD_TEST_CMP="$PWD/tests/.deps/nvim-cmp" \
DADBOD_TEST_BLINK="$PWD/tests/.deps/blink.cmp" \
bash tests/run.sh
```

This pins nvim-cmp to `2ffe79f1f021def8dd1fcd81deb16f1bb0d989f3` and Blink to
v1.7.0. You can point the variables at other installed versions instead. No fuzzy
binary is needed for these pipeline tests. The optional tests are run only when
both environment variables are set.

## Coverage and boundaries

- Standalone SQL/mysql/plsql with Tree-sitter deliberately unavailable; the
  original two-argument omnifunc also runs in Vim with no Lua dependency.
- Real Go and Python parsers, real SQL child trees, and actual injection queries.
- Multiline/same-line regions, table/alias-column/schema completion, quoting,
  explicit byte-based edits (including non-ASCII host lines and mid-word cursors).
- Host code/unrecognized strings, annotation adjacency, delimiter boundaries,
  incomplete SQL, alias isolation, edits, cursor moves and metadata cache reuse.
- Original host-buffer connection/filetype identity and `b:db_table` settings;
  availability checks cannot fetch database metadata.
- Unsupported combined/disjoint ranges and excluded interpolation gaps.
- Missing APIs/host parsers and, in a **fresh process with only go.so installed**,
  a genuinely absent SQL parser. The main suite also simulates transient API and
  parser failures to exercise fail-closed paths.
- Exact README/help Go query equality with the real-parser fixture.

Only database adapter/job I/O is mocked in `tests/runtime/`; production context
detection, connection selection, metadata caching, alias parsing, quoting and
source adapters run unchanged. Engine pipeline tests are headless, not an
interactive menu/keymap or live-database test. Legacy adapters are not given
embedded support by this change.
