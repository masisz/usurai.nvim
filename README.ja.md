# 🧊 usurai.nvim（薄氷）

> **No DAP, No Test Runners, No UI Bloat — Pure Edit, Search & View for Neovim 0.12+**

[English](./README.md) | **日本語**

`usurai.nvim`（薄氷 / うすらい）は、重厚なフルIDE化（デバッガ・テストランナー・大量の言語専用プラグイン・過剰なUI装飾）を削ぎ落とし、Neovim の上に「春先の薄氷のように透き通った極薄のレイヤー」だけを乗せることで、**「爆速で起動し、コードやドキュメントを快適に閲覧（View）・検索（Search）・編集（Edit）すること」**に特化したミニマルな Neovim ディストリビューションプラグインです。

LazyVim と同じように、自分の `~/.config/nvim` から **`{ "masisz/usurai.nvim", import = "usurai.plugins" }`** の 1 行で導入でき、ユーザー独自の `lua/config/` や `lua/plugins/` をクリーンに保てます。

---

## ✨ コンセプトと特徴

- **LazyVim 方式のプラグイン導入 (`import = "usurai.plugins"`)**:
  - ユーザー側の `~/.config/nvim` には最小限の `init.lua` と自分用の差分設定（`lua/config/`, `lua/plugins/`）だけを置く設計です。
- **極限まで絞ったプラグイン構成（約20個）**:
  - LazyVim 等のディストリビューション（60〜80個）でブラックボックス化しがちな構成を脱却し、すべての設定コードが数分で読み切れる完全な透明性を備えています。
- **Neovim 0.12+ の標準機能をフル活用**:
  - 補完エンジン（`nvim-cmp` 等）やスニペットプラグイン（`LuaSnip` 等）を排除し、Neovim 標準の **`vim.lsp.completion`（Fuzzy & Popup対応）** と **`vim.snippet`** で軽快に動作します。
- **Zig ネイティブ検索エンジン（ビルド済みバイナリ同梱・`zig` / `fd` / `rg` インストール不要）**:
  - [masisz/rufio](https://github.com/masisz/rufio) と共通の並列ディレクトリウォーカー＆32バイト SIMD 検索エンジン（`zig/src/search.zig`, `os.zig`）をプラグイン内に同梱。
  - 主要 OS・アーキテクチャ向け（macOS Apple Silicon / Intel、Linux x86_64 / ARM64、Windows x86_64 / ARM64）の**ビルド済みバイナリ（`zig/prebuilt/`）をリポジトリに同梱**しているため、`git clone` した瞬間から Zig コンパイラすら不要で即座に動作します。
  - Neovim の **LuaJIT FFI** から動的ライブラリ（`librufio_zig`）を直接呼び出し、さらに **256MB のオンメモリファイルキャッシュ**をプロセス内に保持するため、外部プロセス起動ゼロ・数ミリ秒での超高速ファイル検索＆Live Grepが動作します。
- **Search & View の中核に `snacks.nvim` を採用**:
  - ファイル検索・Grep・LSPシンボル検索・ファイラーに加え、Markdown やドキュメント内の**インライン画像表示・LaTeX / Typst 数式レンダリング**に対応。
- **Wisteria テーマとクリーンな UI**:
  - [wisteria.nvim](https://github.com/masisz/wisteria.nvim) カラースキームと `lualine.nvim` のみを採用。`noice.nvim` や `bufferline.nvim` を排し、Neovim 本来のレスポンスを損ないません。
- **マルチOS対応（macOS / Windows / Linux）**:
  - OS 判定ヘルパー（`usurai.config.os`）により、PDF/Office/画像の OS 標準ビューア起動やクリップボードからの画像貼り付け（`:PasteImage`）がクロスプラットフォームで動作します。

---

## 📦 インストール（プラグイン導入方式）

### 必須・推奨要件
- **Neovim >= 0.11.0**（**0.12+** 推奨）
- `git`
- （任意）`zig`: 主要環境向けのビルド済みライブラリ（`zig/prebuilt/`）が同梱されているため通常は不要です（ソースから再ビルドしたい場合のみ `:UsuraiZigBuild` で使用）
- （任意）画像・数式インライン表示用: `imagemagick`, `ghostscript`, `tectonic` or `pdflatex`, `typst`, `mermaid-cli`
- （任意）クリップボード画像貼り付け（macOS）: `pngpaste`

### セットアップ方法 (`~/.config/nvim/init.lua` または `lua/config/lazy.lua`)

`lazy.nvim` の `spec` に **`{ "masisz/usurai.nvim", import = "usurai.plugins" }`** を追加します。

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
    -- 1. usurai.nvim 本体とコアプラグイン群をインポート
    {
      "masisz/usurai.nvim",
      import = "usurai.plugins",
      opts = {
        -- 使いたい言語パックを true / false で指定（または下記 extras.lang.* でも可）
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

    -- 2. (任意) LazyVim 風に import 行で言語パックを有効化することも可能
    -- { import = "usurai.plugins.extras.lang.rust" },
    -- { import = "usurai.plugins.extras.lang.go" },

    -- 3. 自分用の追加プラグイン (~/.config/nvim/lua/plugins/*.lua)
    { import = "plugins" },
  },
  install = { colorscheme = { "wisteria", "habamax" } },
  checker = { enabled = true, notify = false },
})
```

### ユーザー側のディレクトリ構成（`~/.config/nvim`）

LazyVim と同様に、ユーザー環境にある以下のファイルも自動的に読み込まれます（存在する場合のみ）：

```text
~/.config/nvim/
├── init.lua                  # lazy.nvim の起動と usurai.plugins のインポート
└── lua/
    ├── config/
    │   ├── options.lua       # (任意) ユーザー独自の vim.opt や vim.g.usurai の上書き
    │   ├── autocmds.lua      # (任意) ユーザー独自の Autocmd
    │   └── keymaps.lua       # (任意) ユーザー独自のキーマップ
    └── plugins/
        └── *.lua             # (任意) ユーザー独自の追加プラグインや設定上書き
```

---

## 🗂 `usurai.nvim` プラグイン内部のモジュール構成

```text
usurai.nvim/
├── zig/                                  # rufio と共通の Zig 検索エンジン（LuaJIT FFI 直結）
│   ├── build.zig                         # `zig build` / `zig build prebuild`（全OS向けクロスビルド）
│   ├── prebuilt/                         # git clone 後すぐ使える各OS・CPU向けビルド済みバイナリ
│   └── src/
│       ├── os.zig                        # OS抽象層（macOS getattrlistbulk / Linux getdents64 / Win32 FindFirstFileExW）
│       ├── search.zig                    # 並列ウォーカー・32byte SIMD 検索・インメモリ Cache
│       └── main.zig                      # C ABI エクスポート（core_search_*, core_files_*, core_cache_*）
├── lua/
│   └── usurai/
│       ├── init.lua                      # require("usurai").setup(opts)
│       ├── health.lua                    # :checkhealth usurai 診断モジュール
│       ├── config/
│       │   ├── init.lua                  # ライフサイクル制御（pre_init → init → setup）
│       │   ├── os.lua                    # OS判定（Mac/Win/Linux）＆ローカル開発プラグイン解決ヘルパー
│       │   ├── options.lua               # 標準オプション設定
│       │   ├── langs.lua                 # Zero-Bloat Language Extras カタログ & :UsuraiLangs
│       │   ├── zig_search.lua            # Zig 検索エンジンの LuaJIT FFI バインディング＆ Snacks.picker Finder
│       │   ├── keymaps.lua               # 基本キーマップ・Super-Tab補完・Markdown見出しショートカット
│       │   └── autocmds.lua              # 外部ファイル起動・:PasteImage・:Today・ヤンクハイライト等
│       └── plugins/
│           ├── init.lua                  # masisz/usurai.nvim コアスペック（priority = 10000）
│           ├── ui.lua                    # [View] wisteria.nvim, lualine, mini.icons, render-markdown, gitsigns
│           ├── snacks.lua                # [Search/View] snacks.nvim (Picker, Explorer, Image/Math viewer)
│           ├── search.lua                # [Search] flash.nvim, grug-far.nvim, which-key.nvim, nvim-tmux-navigation
│           ├── edit.lua                  # [Edit] mini.surround, mini.pairs, mini.ai, lazyclip
│           ├── treesitter.lua            # [View/Edit] nvim-treesitter + endwise
│           ├── lsp.lua                   # [LSP] nvim-lspconfig, mason.nvim, 標準 vim.lsp.completion 設定
│           ├── todo.lua                  # [Task] masisz/todo.nvim 連携
│           └── extras/
│               └── lang/*.lua            # LazyVim 風 `{ import = "usurai.plugins.extras.lang.<lang>" }` モジュール
└── init.lua                              # 単体クローン時のフォールバック起動用エントリーポイント
```

---

## ⌨️ 主なキーマップ

`<leader>` キーは `<Space>` です。

### 🔍 Search（検索・ファイル移動）

| キー | 動作 | プラグイン |
| :--- | :--- | :--- |
| `<leader><space>` / `<leader>ff` | ファイル検索（Zig FFI / Snacks） | `snacks.picker` |
| `<leader>/` / `<leader>sg` | プロジェクト全体の文字列 Grep（Zig SIMD） | `snacks.picker` |
| `<leader>,` / `<leader>fb` | 開いているバッファ一覧 | `snacks.picker` |
| `<leader>fr` | 最近開いたファイル | `snacks.picker` |
| `<leader>sw` | カーソル下の単語 / 選択範囲を Grep | `snacks.picker` |
| `<leader>sb` | 現在のバッファ内を行検索 | `snacks.picker` |
| `<leader>e` | ファイルエクスプローラー開閉 | `snacks.explorer` |
| `<leader>sr` | プロジェクト横断の検索＆一括置換 | `grug-far.nvim` |
| `s` / `S` | 画面内の任意の位置へ高速ジャンプ / Treesitter 選択 | `flash.nvim` |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | ウィンドウ / tmux ペイン間の移動 | `nvim-tmux-navigation` |

### 👀 View & Code Navigation（閲覧・LSPジャンプ）

| キー | 動作 | 備考 |
| :--- | :--- | :--- |
| `gd` / `gr` / `gI` / `gy` | 定義 / 参照 / 実装 / 型定義へジャンプ | `snacks.picker` 連携 |
| `K` | ホバードキュメント表示 | 標準 LSP |
| `<leader>ss` / `<leader>sS` | ファイル内 / ワークスペース全体のシンボル検索 | `snacks.picker` |
| `<S-h>` / `<S-l>`（`[b` / `]b`） | 前 / 次のバッファへ切り替え | 標準バッファ移動 |
| `<leader>bd` | ウィンドウレイアウトを崩さずにバッファを閉じる | `snacks.bufdelete` |
| `]h` / `[h` / `<leader>ghp` | 次/前の Git Hunk 移動・インライン差分プレビュー | `gitsigns.nvim` |
| `<leader>uw` / `<leader>uL` | 折り返し表示（Wrap）/ 相対行番号のトグル | View トグル |

### ✏️ Edit & Markdown / Tasks（編集・タスク管理）

| キー / コマンド | 動作 | 備考 |
| :--- | :--- | :--- |
| `<Tab>` / `<S-Tab>` | 補完候補の選択・スニペットのジャンプ | 標準 `vim.lsp.completion` |
| `<C-Space>` (Insert) | LSP 補完の手動トリガー | 標準 `vim.lsp.completion` |
| `gsa` / `gsd` / `gsr` | 囲み文字（括弧・クォート等）の追加 / 削除 / 置換 | `mini.surround` |
| `<leader>r` | カーソル下の単語を確認付きで置換 (`:%s/.../gc`) | 標準置換 |
| `<leader>Cw` | クリップボード履歴マネージャーを開く | `lazyclip` |
| `<M-1>` 〜 `<M-6>` (Markdown) | `#`〜`####` 見出し、`- ` リスト、`- [ ] ` チェックボックス挿入 | Markdown 専用 |
| `:PasteImage` | クリップボードの画像を保存し Markdown リンクを挿入 | カスタムコマンド |
| `:Today` | 今日の日付（`YYYY/MM/DD`）を挿入 | カスタムコマンド |
| `<leader>Tn` / `<leader>Tl` / `<leader>Tr` | 新規タスク作成 / タスク一覧 / ロードマップ一覧 | [masisz/todo.nvim](https://github.com/masisz/todo.nvim) |
| `:UsuraiLangs` (`<leader>cl`) | 言語パック（Language Extras）の有効状態確認 | `usurai.config.langs` |
| `:UsuraiZigBuild` / `:UsuraiZigStatus` | Zig ネイティブ検索エンジンのビルド / キャッシュ状態確認 | `usurai.config.zig_search` |
| `:checkhealth usurai` | Neovim バージョン・Zig FFI 検索エンジン・外部ツールの診断 | `usurai.health` |

---

## 📄 ライセンス

[MIT](./LICENSE)
