local function augroup(name)
  return vim.api.nvim_create_augroup("usurai_" .. name, { clear = true })
end

-- ============================================================================
-- General Editor Autocmds
-- ============================================================================

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    (vim.hl or vim.highlight).on_yank()
  end,
})

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Restore cursor to last known position when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_loc"),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].usurai_last_loc then
      return
    end
    vim.b[buf].usurai_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close helper filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "checkhealth",
    "grug-far",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "startuptime",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<Cmd>close<CR>", {
      buffer = event.buf,
      silent = true,
      desc = "Quit buffer",
    })
  end,
})

-- ============================================================================
-- Custom File Viewers, Markdown & Utility Commands
-- ============================================================================

-- Open binary/document files in external OS viewer
vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
  group = augroup("open_external"),
  pattern = { "*.pdf", "*.docx", "*.xlsx", "*.pptx", "*.jpg", "*.png" },
  callback = function()
    local os_config = require("usurai.config.os")
    local filepath = vim.fn.expand("<afile>")
    print("open external file: " .. filepath)
    if os_config.is_mac then
      vim.fn.jobstart({ "open", filepath }, { detach = true })
    elseif os_config.is_windows then
      vim.fn.jobstart({ "cmd.exe", "/C", "start", "", filepath }, { detach = true })
    elseif os_config.is_unix then
      vim.fn.jobstart({ "xdg-open", filepath }, { detach = true })
    end
    vim.cmd("bdelete")
  end,
})

-- Disable spellcheck in Markdown
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("markdown_opts"),
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- :PasteImage command (save clipboard image and insert markdown link)
local function paste_image()
  local os_config = require("usurai.config.os")

  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    vim.notify("No file is currently open.")
    return
  end

  local file_dir = vim.fn.fnamemodify(current_file, ":h")
  local file_name = os.date("%Y%m%d_%H%M%S")
  local full_path = os_config.joinpath(file_dir, file_name .. ".png")
  local relative_path = "./" .. file_name .. ".png"

  local cmd
  if os_config.is_mac and os_config.executable("pngpaste") then
    cmd = { "pngpaste", full_path }
  elseif os_config.is_windows and os_config.executable("powershell.exe") then
    local powershell_path = full_path:gsub("'", "''")
    cmd = {
      "powershell.exe",
      "-NoProfile",
      "-Command",
      "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; "
        .. "$img = [Windows.Forms.Clipboard]::GetImage(); "
        .. "if ($null -eq $img) { exit 1 }; "
        .. "$img.Save('"
        .. powershell_path
        .. "', [Drawing.Imaging.ImageFormat]::Png)",
    }
  end

  if not cmd then
    vim.notify("PasteImage is not configured for this OS.", vim.log.levels.WARN)
    return
  end

  vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("No image was saved from the clipboard.", vim.log.levels.WARN)
    return
  end

  local markdown_link = string.format("![%s](%s)", file_name, relative_path)
  vim.api.nvim_put({ markdown_link }, "c", true, true)
  vim.notify("Image saved to " .. full_path)
end

if vim.fn.exists(":PasteImage") == 0 then
  vim.api.nvim_create_user_command("PasteImage", paste_image, { desc = "Paste clipboard image into markdown" })
end

-- :Today command
local function today()
  local title = os.date("%Y/%m/%d")
  vim.api.nvim_put({ title }, "c", true, true)
end

if vim.fn.exists(":Today") == 0 then
  vim.api.nvim_create_user_command("Today", today, { desc = "Insert today's date" })
end

-- Custom filetypes
vim.filetype.add({
  extension = {
    erb = "eruby",
  },
  filename = {
    ["Rakefile"] = "ruby",
  },
})
