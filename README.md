# vim-dadbod-completion

Database auto completion powered by [vim-dadbod](https://github.com/tpope/vim-dadbod).

Supports:
* [coc.nvim](https://github.com/neoclide/coc.nvim)
* [deoplete.nvim](https://github.com/Shougo/deoplete.nvim)
* [nvim-compe](https://github.com/hrsh7th/nvim-compe)
* [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
* [ddc.vim](https://github.com/Shougo/ddc.vim)
* [blink.cmp](https://github.com/Saghen/blink.cmp)
* Built in `omnifunc`

![coc-db](https://user-images.githubusercontent.com/1782860/78941173-717f6680-7ab7-11ea-91b3-18bf178b3735.gif)


Video presentation by TJ:

[![Video presentation by TJ](https://i.ytimg.com/vi/ALGBuFLzDSA/hqdefault.jpg?sqp=-oaymwEcCNACELwBSFXyq4qpAw4IARUAAIhCGAFwAcABBg==&rs=AOn4CLDmOFtUnDmQx5U_PKBqV819YujOBw)](https://www.youtube.com/watch?v=ALGBuFLzDSA)


## Install

**Dependencies**:
* [vim-dadbod](https://github.com/tpope/vim-dadbod)

For [coc.nvim](https://github.com/neoclide/coc.nvim)
```
:CocInstall coc-db
```

For `deoplete`, `completion-nvim`, `nvim-compe`, `ddc` and `omnifunc`, install it with your favorite plugin manager.

```vim
Plug 'tpope/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-ui' "Optional
Plug 'kristijanhusak/vim-dadbod-completion'

" For built in omnifunc
autocmd FileType sql setlocal omnifunc=vim_dadbod_completion#omni

" hrsh7th/nvim-compe
let g:compe.source.vim_dadbod_completion = v:true

" hrsh7th/nvim-cmp
  autocmd FileType sql,mysql,plsql lua require('cmp').setup.buffer({ sources = {{ name = 'vim-dadbod-completion' }} })

" Shougo/ddc.vim
call ddc#custom#patch_filetype(['sql', 'mysql', 'plsql'], 'sources', 'dadbod-completion')
call ddc#custom#patch_filetype(['sql', 'mysql', 'plsql'], 'sourceOptions', {
\ 'dadbod-completion': {
\   'mark': 'DB',
\   'isVolatile': v:true,
\ },
\ })
```

Configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) with [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui)
```lua
return {
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', lazy = true },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },
  { -- optional saghen/blink.cmp completion source
    'saghen/blink.cmp',
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          sql = { 'snippets', 'dadbod', 'buffer' },
        },
        -- add vim-dadbod-completion to your completion providers
        providers = {
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
        },
      },
    },
  }
}
```

## Features
* Autocomplete table names, with automatic quoting where needed. Works for all schemes that [vim-dadbod](https://github.com/tpope/vim-dadbod) supports.
* Autocomplete table columns, context aware. Also knows to read aliases (`select * from mytable tbl where tbl.id = 1`). Currently works for `PostgreSQL`, `MySQL`, `Oracle`, `SQLite` (requires version `3.37.0 (2021-11-27)`) and `SQLserver/MSSQL`.
* Out of the box integration with [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui)

## How it works
* If an sql buffer is created by [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), it reads all the configuration from there. It should work out of the box.
* If `vim-dadbod-ui` is not used, there are multiple ways to define the connection string, prioritized by this order:
  * Window variable - example: `let w:db = 'postgresql://user:pass@localhost:5432/db_name'`
  * Tab variable - example: `let t:db = 'postgresql://user:pass@localhost:5432/db_name'`
  * Buffer variable - example: `let b:db = 'postgresql://user:pass@localhost:5432/db_name'`. You can also add `let b:db_table = 'table_name'` to limit column completions only to this table
  * Global variable - example: `let g:db = 'postgresql://user:pass@localhost:5432/db_name'`
  * `$DATABASE_URL` env variable, defined outside of Vim, or inside with `let $DATABASE_URL = 'postgresql://user:pass@localhost:5432/db_name'`

## Embedded SQL (Neovim)

Blink and nvim-cmp can complete SQL inside **existing Tree-sitter injections** in
any host language. Standalone `sql`, `mysql`, and `plsql` buffers still work in
Vim/Neovim without Tree-sitter. Embedded completion requires **Neovim 0.10+**
(tested on 0.10.4 and 0.12.2), compatible host and SQL parsers, and an injection
query exposing language `sql`, `mysql`, or `plsql`. The `nvim-treesitter` plugin
itself is not required; parsers and queries on Neovim's runtimepath suffice.

**Injection queries identify SQL; Dadbod consumes those injections.** Dadbod does
not recognize comment markers, install injection queries, or turn ordinary
strings into SQL. Configure injections yourself or use a query package. Missing
parsers or unrecognized strings simply disable this source. Incomplete SQL is
supported as long as the host parser/query can still identify its region.

### Load and register the source in host buffers

The SQL-only lazy-loading and `per_filetype.sql` examples above are **not enough**
for embedded SQL. Load Dadbod completion for host buffers too, and include its
source alongside your normal language sources. For example, with lazy.nvim and
Blink (merge this into your existing Blink specification):

```lua
{
  'saghen/blink.cmp',
  version = '1.*',
  dependencies = {
    {
      'kristijanhusak/vim-dadbod-completion',
      dependencies = { 'tpope/vim-dadbod' },
      -- No SQL-only `ft` restriction.
    },
  },
  opts = {
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer', 'dadbod' },
      providers = {
        dadbod = { name = 'Dadbod', module = 'vim_dadbod_completion.blink' },
      },
    },
  },
}
```

If you already override `sources.per_filetype.go` (or another host filetype), add
`dadbod` there as well. Do not replace your host-language sources with Dadbod.
Both availability and completion requests are guarded by the SQL context.

For nvim-cmp, load this plugin and `vim-dadbod` alongside nvim-cmp (not only on SQL
FileType). Its `after/plugin` script registers `vim-dadbod-completion`. Include it
in your normal source list, for example:

```lua
local cmp = require('cmp')
cmp.setup({
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'vim-dadbod-completion' },
    { name = 'buffer' },
    { name = 'path' },
    -- Keep your existing snippet and other sources here too.
  }),
})
```

Filetype-specific cmp source lists must also include it. If manually loading
plugins in an order that skips automatic registration, register it after cmp:

```lua
cmp.register_source('vim-dadbod-completion',
  require('vim_dadbod_completion').nvim_cmp_source)
```

Set the database connection on the **original host buffer**, for example in Go:

```vim
:let b:db = 'postgresql://user:pass@localhost:5432/db_name'
```

Normal DBUI connection settings and the `w:db`, `t:db`, `b:db`, `g:db`,
`$DATABASE_URL` precedence above still apply, as do `b:db_table` and buffer-local
bind parameters. No scratch buffer, filetype change, or synthetic DBUI settings
are needed. Metadata is fetched on completion, not availability checks, and the
existing connection-keyed cache is shared. Use `:DBCompletionClearCache` after
schema changes.

### Tested Go injection example (opt-in)

Install compatible `go` and `sql` parsers using your parser manager (for example,
`:TSInstall go sql` with nvim-treesitter versions providing that command). Then
create **`~/.config/nvim/after/queries/go/injections.scm`** (more generally,
`stdpath('config') .. '/after/queries/go/injections.scm'`) with these exact contents.
Keep `; extends` so existing Go queries are extended rather than replaced:

```scheme
; extends

; Newer Go grammars wrap statements in statement_list; older ones do not.
; Use a wildcard for that wrapper so both grammar versions accept this query.
([
  (block
    (comment) @_sql
    . (_
        . (short_var_declaration
            right: (expression_list
              (raw_string_literal (raw_string_literal_content) @injection.content)))))
  ((comment) @_sql
   . (short_var_declaration
       right: (expression_list
         (raw_string_literal (raw_string_literal_content) @injection.content))))
 ]
 (#eq? @_sql "// language=SQL")
 (#set! injection.language "sql"))
```

Restart Neovim after installing/changing queries, then open a Go file containing:

```go
// language=SQL
query := `
    SELECT p.id, p.name
    FROM products AS p
    WHERE p.id = $1
`
```

Put this declaration inside a function. The query matches a directly preceding
`// language=SQL` comment and the intended short declaration's raw-string content,
not its backticks or other strings. The annotation is **a convention of this
example query**, not a universal built-in Tree-sitter directive or Dadbod marker.
The test fixtures verify this query against real Go grammars, including the
`tree-sitter-go` v0.23.4 layout and newer `statement_list` layouts.

With the Blink setup above and `b:db` set, type `p.` inside this string and request
completion (`<C-Space>` with Blink's default keymap) to see `products` columns;
type `pro` after `FROM` for table completion. Dadbod stays inactive outside
recognized injections; your normal Go sources remain available.

### Scope and limitations

- Each active injection is independent: aliases from another string cannot leak
  into it. Prefix detection, quoting and completion edits use SQL-local text;
  connection settings belong to the host buffer.
- Only a single contiguous included range per SQL tree is supported. Combined or
  disjoint injections with multiple included ranges are rejected, not joined;
  excluded host content is never scanned as SQL. Query authors must exclude host
  delimiters and provide accurate content ranges.
- Cursor positions are insertion points: immediately after an opening delimiter
  and immediately before a closing delimiter are inside; before the opening or
  after the closing delimiter are outside.
- Concatenation, interpolation and function calls are not reconstructed into a
  query. Host syntax broken enough to lose its injection cannot be completed.
- Items are inserted as SQL text, without host-language string escaping. Choose
  string delimiters that do not conflict with your database's identifier quotes.
- Alias analysis is the existing lightweight, line-based parser, not a full SQL
  parser. Embedded support is provided by Blink and nvim-cmp; legacy adapters and
  the public two-argument omnifunc retain their standalone behavior.

See [tests/README.md](tests/README.md) for reproducible headless parser tests.

## Settings
Default mark for completion items is `[DB]`. To change it, add this to vimrc:
```
let g:vim_dadbod_completion_mark = 'MYMARK'
```

## Commands
This plugin caches the database tables and columns to leverage maximum performance. If you want to clear the cache at any point just run:

```
:DBCompletionClearCache
```

## Todo
* [ ] Integration for column autocompletion with more database types
