local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

function M.check()
  start("usurai.nvim Core")

  if vim.fn.has("nvim-0.12.0") == 1 then
    ok(string.format("Neovim version: %s (0.12+ native completion & fuzzy popup supported)", tostring(vim.version())))
  elseif vim.fn.has("nvim-0.11.0") == 1 then
    warn(
      string.format("Neovim version: %s (0.12+ is recommended for native completion)", tostring(vim.version()))
    )
  else
    error(string.format("Neovim >= 0.11.0 is required (current: %s)", tostring(vim.version())))
  end

  if vim.fn.executable("git") == 1 then
    ok("`git` is installed")
  else
    error("`git` is not installed")
  end

  start("usurai.nvim Zig Native Search Engine (librufio_zig)")
  local zig_search = require("usurai.config.zig_search")
  local lib_path = zig_search.lib_path()
  if zig_search.is_available() then
    ok(string.format("Loaded via LuaJIT FFI: %s", lib_path))
  else
    warn(string.format("Shared library not loaded (%s). Run `:UsuraiZigBuild` to compile.", lib_path))
  end

  if vim.fn.executable("zig") == 1 then
    local zig_ver = vim.fn.system({ "zig", "version" }):gsub("%s+$", "")
    ok(string.format("`zig` compiler found (%s) — optional when using bundled prebuilt library", zig_ver))
  else
    info("`zig` compiler not found in PATH — optional (bundled prebuilt library is used out-of-the-box)")
  end

  start("usurai.nvim Optional External Tools")
  local optional_tools = {
    { cmd = "rg", desc = "Fallback grep tool when Zig search is disabled" },
    { cmd = "fd", desc = "Fallback file finder when Zig search is disabled" },
    { cmd = "magick", desc = "ImageMagick for Snacks inline image/math conversion" },
    { cmd = "tectonic", desc = "LaTeX engine for Snacks inline math rendering (or pdflatex)" },
    { cmd = "typst", desc = "Typst compiler for Snacks inline math rendering" },
    { cmd = "mmdc", desc = "Mermaid CLI for rendering Mermaid diagrams" },
  }

  local os_config = require("usurai.config.os")
  if os_config.is_mac then
    table.insert(optional_tools, { cmd = "pngpaste", desc = "Clipboard image pasting (:PasteImage) on macOS" })
  end

  for _, tool in ipairs(optional_tools) do
    if vim.fn.executable(tool.cmd) == 1 then
      ok(string.format("`%s` found (%s)", tool.cmd, tool.desc))
    else
      info(string.format("`%s` not found — optional (%s)", tool.cmd, tool.desc))
    end
  end

  start("usurai.nvim Language Extras")
  local langs_mod = require("usurai.config.langs")
  local resolved = langs_mod.resolve()
  local cfg = vim.g.usurai or {}
  local enabled_langs = {}
  for name, enabled in pairs(cfg.langs or {}) do
    if enabled then
      table.insert(enabled_langs, name)
    end
  end
  table.sort(enabled_langs)
  ok("Enabled language packs: " .. (#enabled_langs > 0 and table.concat(enabled_langs, ", ") or "(none)"))
  info("Configured LSP servers: " .. table.concat(vim.tbl_keys(resolved.servers), ", "))
end

return M
