local M = {}

---@class UsuraiOptions
---@field use_local_dev? boolean
---@field enable_todo? boolean
---@field zig_search? boolean
---@field colorscheme? string
---@field wisteria? table
---@field todo? table
---@field langs? table<string, boolean>
---@field custom_servers? table<string, table>
M.defaults = {
  -- Use local plugin directories in ~/devs (or $NVIM_DEV_DIR) when explicitly enabled
  use_local_dev = false,
  -- Enable built-in task manager plugin (masisz/todo.nvim)
  enable_todo = true,
  -- Use bundled Zig native search engine via LuaJIT FFI (replaces external `fd` and `rg`)
  zig_search = true,
  -- Default colorscheme
  colorscheme = "wisteria",

  -- Language Extras: set to `true` to enable Tree-sitter parsers + minimal LSP
  langs = {
    lua        = true,  -- lua_ls
    python     = true,  -- pyright
    typescript = true,  -- vtsls (TS/JS/TSX)
    web        = true,  -- html, css, vue, svelte, emmet_ls
    data       = true,  -- json, yaml, toml
    markdown   = true,  -- marksman + markdown/latex/typst parsers
    ruby       = true,  -- ruby_lsp
    cpp        = true,  -- clangd (with Unreal Engine .uproject support)
    godot      = true,  -- gdscript
    rust       = false, -- rust_analyzer
    go         = false, -- gopls
    csharp     = false, -- omnisharp (C# / Razor)
    zig        = false, -- zls
    sql        = false, -- sqlls (SQL syntax & LSP)
  },

  custom_servers = {},
}

local did_pre_init = false
local did_init = false
local did_setup = false

--- Load a user config module (`config.<name>`) if it exists in the user's `~/.config/nvim/lua/config/`
---@param name string
local function load_user_config(name)
  local user_file = vim.fn.stdpath("config") .. "/lua/config/" .. name .. ".lua"
  if vim.uv.fs_stat(user_file) then
    pcall(require, "config." .. name)
  end
end

--- Called as soon as `usurai.plugins` is imported by `lazy.nvim` (before specs are parsed)
function M.pre_init()
  if did_pre_init then
    return
  end
  did_pre_init = true

  vim.g.mapleader = vim.g.mapleader or " "
  vim.g.maplocalleader = vim.g.maplocalleader or "\\"

  vim.g.usurai = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), vim.g.usurai or {})
end

--- Called in `usurai.nvim` plugin `init()` before plugins load
function M.init()
  if did_init then
    return
  end
  did_init = true

  M.pre_init()
  require("usurai.config.options")
  load_user_config("options")

  -- Re-merge in case user's `config/options.lua` assigned a partial `vim.g.usurai` table
  vim.g.usurai = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), vim.g.usurai or {})
end

--- Called in `usurai.nvim` plugin `config(_, opts)` (priority = 10000)
---@param opts? UsuraiOptions
function M.setup(opts)
  M.init()
  if opts and type(opts) == "table" then
    vim.g.usurai = vim.tbl_deep_extend("force", vim.g.usurai or {}, opts)
  end

  if did_setup then
    return
  end
  did_setup = true

  require("usurai.config.langs")
  require("usurai.config.zig_search")
  require("usurai.config.autocmds")
  require("usurai.config.keymaps")

  load_user_config("autocmds")
  load_user_config("keymaps")

  if vim.fn.exists(":LspInfo") == 0 then
    vim.api.nvim_create_user_command("LspInfo", function()
      vim.cmd("checkhealth vim.lsp")
    end, { desc = "Show LSP health information" })
  end
end

return M
