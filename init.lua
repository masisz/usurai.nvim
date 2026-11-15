-- ============================================================================
-- usurai.nvim — Standalone / Starter Entrypoint
-- Recommended usage (LazyVim-style plugin import in your own ~/.config/nvim):
--   require("lazy").setup({
--     spec = {
--       { "masisz/usurai.nvim", import = "usurai.plugins", opts = { ... } },
--       { import = "plugins" },
--     },
--   })
-- ============================================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local spec = {
  {
    "masisz/usurai.nvim",
    dir = vim.fn.stdpath("config"),
    name = "usurai.nvim",
    import = "usurai.plugins",
  },
}

if vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/plugins") then
  table.insert(spec, { import = "plugins" })
end

require("lazy").setup({
  spec = spec,
  defaults = {
    lazy = false,
    version = false,
  },
  install = {
    colorscheme = { "wisteria", "habamax" },
  },
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
