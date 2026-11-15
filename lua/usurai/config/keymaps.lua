local map = vim.keymap.set

-- ============================================================================
-- Custom Editing Keymaps
-- ============================================================================

-- Select all
map("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

-- Delete a word backwards without yanking
map("n", "dw", 'vb"_d', { desc = "Delete word backwards" })

-- Do not yank with x / X
map("n", "x", '"_x', { desc = "Delete char without yank" })
map("n", "X", '"_X', { desc = "Delete char backward without yank" })

-- Paste in command-line mode
map("c", "<C-v>", "<C-r>+", { desc = "Paste from clipboard" })
map("c", "<D-v>", "<C-r>+", { desc = "Paste from clipboard" })

-- Native completion & snippet Super-Tab
map({ "i", "s" }, "<Tab>", function()
  if vim.fn.pumvisible() == 1 then
    return "<C-n>"
  elseif vim.snippet.active({ direction = 1 }) then
    vim.schedule(function()
      vim.snippet.jump(1)
    end)
    return ""
  end
  return "<Tab>"
end, { expr = true, silent = true, desc = "Next completion item or snippet jump" })

map({ "i", "s" }, "<S-Tab>", function()
  if vim.fn.pumvisible() == 1 then
    return "<C-p>"
  elseif vim.snippet.active({ direction = -1 }) then
    vim.schedule(function()
      vim.snippet.jump(-1)
    end)
    return ""
  end
  return "<S-Tab>"
end, { expr = true, silent = true, desc = "Prev completion item or snippet jump" })

map("i", "<CR>", function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
    return "<C-y>"
  end
  return "<CR>"
end, { expr = true, silent = true, desc = "Confirm completion" })

-- Replace word under cursor (with confirmation)
map(
  "n",
  "<leader>r",
  ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gc<Left><Left><Left>",
  { desc = "Replace word under cursor (confirm)" }
)

-- ============================================================================
-- General Navigation, Buffer, Window & View Keymaps
-- ============================================================================

-- Better up/down on wrapped lines
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up" })

-- Clear search highlight with <Esc>
map({ "i", "n" }, "<Esc>", "<Cmd>noh<CR><Esc>", { desc = "Escape and clear hlsearch" })

-- Keep visual selection when indenting
map("v", "<", "<gv", { desc = "Outdent selection" })
map("v", ">", ">gv", { desc = "Indent selection" })

-- Move lines up/down
map("n", "<A-j>", "<Cmd>execute 'move .+' . v:count1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<Cmd>execute 'move .-' . (v:count1 + 1)<CR>==", { desc = "Move line up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<CR>gv=gv", { desc = "Move selection down", silent = true })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<CR>gv=gv", { desc = "Move selection up", silent = true })

-- Window navigation (overridden by nvim-tmux-navigation when loaded)
map("n", "<C-h>", "<Cmd>NvimTmuxNavigateLeft<CR>", { desc = "Go to left window/pane" })
map("n", "<C-j>", "<Cmd>NvimTmuxNavigateDown<CR>", { desc = "Go to lower window/pane" })
map("n", "<C-k>", "<Cmd>NvimTmuxNavigateUp<CR>", { desc = "Go to upper window/pane" })
map("n", "<C-l>", "<Cmd>NvimTmuxNavigateRight<CR>", { desc = "Go to right window/pane" })

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", "<Cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<Cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Window splits
map("n", "<leader>-", "<C-W>s", { desc = "Split window below" })
map("n", "<leader>|", "<C-W>v", { desc = "Split window right" })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete window" })

-- Buffer navigation
map("n", "<S-h>", "<Cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<S-l>", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "[b", "<Cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "]b", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bb", "<Cmd>e #<CR>", { desc = "Switch to other buffer" })
map("n", "<leader>bd", function()
  if _G.Snacks then
    Snacks.bufdelete()
  else
    vim.cmd("bdelete")
  end
end, { desc = "Delete buffer" })

-- Save & Quit
map({ "i", "x", "n", "s" }, "<C-s>", "<Cmd>w<CR><Esc>", { desc = "Save file" })
map("n", "<leader>qq", "<Cmd>qa<CR>", { desc = "Quit all" })

-- Diagnostics
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next Diagnostic" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Prev Diagnostic" })

-- View toggles
map("n", "<leader>uw", function()
  vim.opt_local.wrap = not vim.opt_local.wrap:get()
end, { desc = "Toggle Word Wrap" })
map("n", "<leader>uL", function()
  vim.opt_local.relativenumber = not vim.opt_local.relativenumber:get()
end, { desc = "Toggle Relative Number" })
map("n", "<leader>ul", function()
  vim.opt_local.number = not vim.opt_local.number:get()
end, { desc = "Toggle Line Numbers" })

-- ============================================================================
-- Markdown Editing Shortcuts
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("usurai_markdown_keys", { clear = true }),
  pattern = "markdown",
  callback = function()
    local opts = { silent = true, buffer = true }

    -- Insert: 行頭に入れて Insert に戻る
    map("i", "<M-1>", "<Esc>I# <Esc>i", opts)
    map("i", "<M-2>", "<Esc>I## <Esc>i", opts)
    map("i", "<M-3>", "<Esc>I### <Esc>i", opts)
    map("i", "<M-4>", "<Esc>I#### <Esc>i", opts)
    map("i", "<M-5>", "<Esc>I- <Esc>i", opts)
    map("i", "<M-6>", "<Esc>I- [ ] <Esc>i", opts)

    -- Normal: 行頭に入れて Normal のまま
    map("n", "<M-1>", "I# <Esc>", opts)
    map("n", "<M-2>", "I## <Esc>", opts)
    map("n", "<M-3>", "I### <Esc>", opts)
    map("n", "<M-4>", "I#### <Esc>", opts)
    map("n", "<M-5>", "I- <Esc>", opts)
    map("n", "<M-6>", "I- [ ] <Esc>", opts)
  end,
})
