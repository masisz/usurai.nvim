-- ============================================================================
-- usurai.nvim Default Options
-- Users can override any of these in `~/.config/nvim/lua/config/options.lua`
-- or configure `usurai` via `{ "masisz/usurai.nvim", opts = { ... } }`.
-- ============================================================================

vim.g.mapleader = vim.g.mapleader or " "
vim.g.maplocalleader = vim.g.maplocalleader or "\\"

-- Disable autoformat by default
if vim.g.autoformat == nil then
  vim.g.autoformat = false
end

local opt = vim.opt

-- General & System
opt.autowrite = true
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
opt.confirm = true
opt.mouse = "a"
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200
opt.timeoutlen = 300

-- UI & View
opt.termguicolors = true
opt.cursorline = false
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.laststatus = 3
opt.showmode = false
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.smoothscroll = true
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"
opt.wrap = false
opt.linebreak = true
opt.virtualedit = "block"
opt.shortmess:append({ W = true, I = true, c = true, C = true })

-- Search & Replace
opt.hlsearch = false
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "nosplit"
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"

-- Editing, Indentation & Native Completion (Neovim 0.12+)
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.shiftround = true
opt.smartindent = true
opt.completeopt = "menu,menuone,noselect,fuzzy,popup"
opt.wildmode = "longest:full,full"

-- Cursor appearance (non-blinking)
opt.guicursor = {
  "n-v-c:block-blinkon0",
  "i-ci-ve:ver25-blinkon0",
  "r-cr:hor20-blinkon0",
  "o:hor50-blinkon0",
  "sm:block-blinkon0",
}
