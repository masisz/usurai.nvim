# 🧊 usurai.nvim (薄氷)

> **No DAP, No Test Runners, No UI Bloat — Pure Edit, Search & View for Neovim 0.12+**

**English** | [日本語](./README.ja.md)

`usurai.nvim` (*usurai* / 薄氷, meaning "thin ice in early spring") is a minimal Neovim distribution plugin focused purely on **blazing-fast startup and a seamless experience for viewing (View), searching (Search), and editing (Edit) code and documents**—stripping away heavy IDE bloat such as debuggers (DAP), test runners, bulky language-specific plugins, and excessive UI decorations to place only a crystal-clear, ultra-thin layer over Neovim.

Just like LazyVim, you can install it from your `~/.config/nvim` with a single line—**`{ "masisz/usurai.nvim", import = "usurai.plugins" }`**—keeping your personal `lua/config/` and `lua/plugins/` clean and maintainable.

---

## ✨ Philosophy & Features

- **LazyVim-Style Plugin Import (`import = "usurai.plugins"`)**:
  - Keep only a minimal `init.lua` and your own overrides (`lua/config/`, `lua/plugins/`) in `~/.config/nvim`.
- **Radically Curated Plugin Set (~20 plugins)**:
  - Breaks away from the 60–80 plugin black-box setups common in full distributions. Every line of configuration can be read and understood in minutes.
- **Built on Native Neovim 0.12+ Features**:
  - Replaces external completion engines (`nvim-cmp`) and snippet plugins (`LuaSnip`) with Neovim's built-in **`vim.lsp.completion` (with Fuzzy & Popup support)** and **`vim.snippet`**.
- **Bundled Zig Native Search Engine (Prebuilt binaries included — no `zig`, `fd`, or `rg` required)**:
  - Ships with the parallel directory walker and 32-byte SIMD search engine (`zig/src/search.zig`, `os.zig`) and the fuzzy matcher (`fuzzy.zig`) shared with [masisz/rufio](https://github.com/masisz/rufio).
  - Live Grep can fuzzy-filter its hits: type `pattern  filter` (two spaces) to grep `pattern` literally, then rank the hits by a fuzzy match of `filter` against `path:line:col:text` (e.g. `def  fzsess`).
  - Includes **prebuilt shared libraries (`zig/prebuilt/`) for all major platforms** (macOS Apple Silicon / Intel, Linux x86_64 / ARM64, Windows x86_64 / ARM64), so it works out-of-the-box right after `git clone` without needing the Zig compiler installed.
  - Calls the shared library (`librufio_zig`) directly from Neovim's **LuaJIT FFI**. Combined with an **in-process 256MB in-memory file cache**, it delivers zero-subprocess, sub-millisecond file search and live grep.
- **`snacks.nvim` at the Core of Search & View**:
  - Powers file finding, live grep, LSP symbol search, and the file explorer, plus **inline image rendering and LaTeX / Typst math rendering** inside Markdown and documentation files.
- **Wisteria Theme & Clean UI**:
  - Uses only the [wisteria.nvim](https://github.com/masisz/wisteria.nvim) colorscheme and `lualine.nvim`. Avoids heavy UI overrides like `noice.nvim` or `bufferline.nvim` to preserve Neovim's native responsiveness.
- **Cross-Platform Support (macOS / Windows / Linux)**:
  - Includes an OS detection helper (`usurai.config.os`) for opening PDFs/Office docs/images in the system viewer and pasting clipboard images (`:PasteImage`) across platforms.

---

## 📦 Installation (Plugin Import Method)

### Requirements
- **Neovim >= 0.11.0** (**0.12+** recommended)
- `git`
- *(Optional)* `zig`: Not required for normal use since prebuilt binaries (`zig/prebuilt/`) are bundled for major platforms (only needed if you want to rebuild from source via `:UsuraiZigBuild`)
- *(Optional)* Inline image & math rendering: `imagemagick`, `ghostscript`, `tectonic` or `pdflatex`, `typst`, `mermaid-cli`
- *(Optional)* Clipboard image pasting on macOS: `pngpaste`

### Setup (`~/.config/nvim/init.lua` or `lua/config/lazy.lua`)

Add **`{ "masisz/usurai.nvim", import = "usurai.plugins" }`** to your `lazy.nvim` `spec`:

```lua
-- ~/.config/nvim/init.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- 1. Import usurai.nvim core and plugins
    {
      "masisz/usurai.nvim",
      import = "usurai.plugins",
      opts = {
        -- Enable/disable language packs via true / false (or via extras.lang.* imports below)
        langs = {
          lua        = true,
          python     = true,
          typescript = true,
          web        = true,
          data       = true,
          markdown   = true,
          ruby       = true,
          cpp        = true,
          godot      = true,
          rust       = false,
          go         = false,
          csharp     = false,
          zig        = false,
          sql        = false,
        },
      },
    },

    -- 2. (Optional) Enable language packs via LazyVim-style import lines
    -- { import = "usurai.plugins.extras.lang.rust" },
    -- { import = "usurai.plugins.extras.lang.go" },

    -- 3. Your own custom plugins (~/.config/nvim/lua/plugins/*.lua)
    { import = "plugins" },
  },
  install = { colorscheme = { "wisteria", "habamax" } },
  checker = { enabled = true, notify = false },
})
```

### User Directory Structure (`~/.config/nvim`)

Just like LazyVim, the following files in your user configuration directory are automatically loaded if present:

```text
~/.config/nvim/
├── init.lua                  # Bootstraps lazy.nvim and imports usurai.plugins
└── lua/
    ├── config/
    │   ├── options.lua       # (Optional) User overrides for vim.opt or vim.g.usurai
    │   ├── autocmds.lua      # (Optional) User custom Autocmds
    │   └── keymaps.lua       # (Optional) User custom Keymaps
    └── plugins/
        └── *.lua             # (Optional) User additional plugins or plugin overrides
```

---

## 🗂 Internal Architecture of `usurai.nvim`

```text
usurai.nvim/
├── zig/                                  # Zig search engine shared with rufio (via LuaJIT FFI)
│   ├── build.zig                         # `zig build` / `zig build prebuild` (cross-compiles all targets)
│   ├── prebuilt/                         # Prebuilt shared libraries for immediate out-of-the-box use
│   └── src/
│       ├── fuzzy.zig                     # Fuzzy matcher shared with rufio (top-K, UTF-8)
│       ├── os.zig                        # OS abstraction (macOS getattrlistbulk / Linux getdents64 / Win32 FindFirstFileExW)
│       ├── search.zig                    # Parallel walker, 32-byte SIMD search & in-memory cache
│       └── main.zig                      # C ABI exports (core_search_*, core_files_*, core_cache_*, core_fuzzy_*)
├── lua/
│   └── usurai/
│       ├── init.lua                      # require("usurai").setup(opts)
│       ├── health.lua                    # :checkhealth usurai diagnostics
│       ├── config/
│       │   ├── init.lua                  # Lifecycle management (pre_init → init → setup)
│       │   ├── os.lua                    # OS detection (Mac/Win/Linux) & local dev plugin helper
│       │   ├── options.lua               # Default Neovim options
│       │   ├── langs.lua                 # Zero-Bloat Language Extras catalog & :UsuraiLangs
│       │   ├── zig_search.lua            # LuaJIT FFI bindings for Zig search & Snacks.picker custom finders
│       │   ├── keymaps.lua               # Core keymaps, Super-Tab completion & Markdown heading shortcuts
│       │   └── autocmds.lua              # External file opener, :PasteImage, :Today, yank highlight, etc.
│       └── plugins/
│           ├── init.lua                  # masisz/usurai.nvim core spec (priority = 10000)
│           ├── ui.lua                    # [View] wisteria.nvim, lualine, mini.icons, render-markdown, gitsigns
│           ├── snacks.lua                # [Search/View] snacks.nvim (Picker, Explorer, Image/Math viewer)
│           ├── search.lua                # [Search] flash.nvim, grug-far.nvim, which-key.nvim, nvim-tmux-navigation
│           ├── edit.lua                  # [Edit] mini.surround, mini.pairs, mini.ai, lazyclip
│           ├── treesitter.lua            # [View/Edit] nvim-treesitter + endwise
│           ├── lsp.lua                   # [LSP] nvim-lspconfig, mason.nvim, native vim.lsp.completion setup
│           ├── todo.lua                  # [Task] masisz/todo.nvim integration
│           └── extras/
│               └── lang/*.lua            # LazyVim-style `{ import = "usurai.plugins.extras.lang.<lang>" }` modules
└── init.lua                              # Fallback entry point when cloned directly as ~/.config/nvim
```

---

## ⌨️ Keymaps

The `<leader>` key is `<Space>`.

### 🔍 Search & File Navigation

| Key | Action | Plugin |
| :--- | :--- | :--- |
| `<leader><space>` / `<leader>ff` | Find files (Zig FFI / Snacks) | `snacks.picker` |
| `<leader>/` / `<leader>sg` | Live Grep across project (Zig SIMD; `pattern  filter` fuzzy-filters hits) | `snacks.picker` |
| `<leader>,` / `<leader>fb` | Open buffers | `snacks.picker` |
| `<leader>fr` | Recent files | `snacks.picker` |
| `<leader>sw` | Grep word under cursor / visual selection | `snacks.picker` |
| `<leader>sb` | Search lines in current buffer | `snacks.picker` |
| `<leader>e` | Toggle file explorer | `snacks.explorer` |
| `<leader>sr` | Project-wide search & replace | `grug-far.nvim` |
| `s` / `S` | Flash jump / Treesitter node selection | `flash.nvim` |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Navigate across windows and tmux panes | `nvim-tmux-navigation` |

### 👀 View & Code Navigation

| Key | Action | Notes |
| :--- | :--- | :--- |
| `gd` / `gr` / `gI` / `gy` | Goto Definition / References / Implementation / Type Definition | `snacks.picker` |
| `K` | Show Hover documentation | Native LSP |
| `<leader>ss` / `<leader>sS` | Document symbols / Workspace symbols | `snacks.picker` |
| `<S-h>` / `<S-l>` (`[b` / `]b`) | Previous / Next buffer | Native buffer nav |
| `<leader>bd` | Delete buffer without closing window layout | `snacks.bufdelete` |
| `]h` / `[h` / `<leader>ghp` | Next/Prev Git hunk & preview hunk inline | `gitsigns.nvim` |
| `<leader>uw` / `<leader>uL` | Toggle line wrap / relative line numbers | View toggles |

### ✏️ Edit, Markdown & Tasks

| Key / Command | Action | Notes |
| :--- | :--- | :--- |
| `<Tab>` / `<S-Tab>` | Select completion item / Jump snippet placeholders | Native `vim.lsp.completion` |
| `<C-Space>` (Insert) | Trigger LSP completion manually | Native `vim.lsp.completion` |
| `gsa` / `gsd` / `gsr` | Add / Delete / Replace surrounding pair | `mini.surround` |
| `<leader>r` | Replace word under cursor with confirmation (`:%s/.../gc`) | Native substitute |
| `<leader>Cw` | Open clipboard history manager | `lazyclip` |
| `<M-1>` – `<M-6>` (Markdown) | Insert `#`–`####` headings, `- ` list, or `- [ ] ` checkbox | Markdown buffer local |
| `:PasteImage` | Save clipboard image and insert Markdown link | Custom command |
| `:Today` | Insert today's date (`YYYY/MM/DD`) | Custom command |
| `<leader>Tn` / `<leader>Tl` / `<leader>Tr` | New task / Task list / Roadmap list | [masisz/todo.nvim](https://github.com/masisz/todo.nvim) |
| `:UsuraiLangs` (`<leader>cl`) | Check status of Language Extras | `usurai.config.langs` |
| `:UsuraiZigBuild` / `:UsuraiZigStatus` | Build Zig native search engine / Inspect cache & FFI status | `usurai.config.zig_search` |
| `:checkhealth usurai` | Diagnose Neovim version, Zig FFI search engine, and optional tools | `usurai.health` |

---

## 📄 License

[MIT](./LICENSE)
