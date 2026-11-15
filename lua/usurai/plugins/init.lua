-- ============================================================================
-- usurai.nvim Core Plugin Entrypoint (LazyVim-style plugin distribution)
-- Usage in user's `lazy.nvim` spec:
--   { "masisz/usurai.nvim", import = "usurai.plugins", opts = { ... } }
-- ============================================================================

require("usurai.config").pre_init()

return {
  {
    "masisz/usurai.nvim",
    priority = 10000,
    lazy = false,
    opts = {},
    build = function()
      local zig_search = require("usurai.config.zig_search")
      if not zig_search.is_available() and vim.fn.executable("zig") == 1 then
        zig_search.build(true)
      end
    end,
    init = function()
      require("usurai.config").init()
    end,
    config = function(_, opts)
      require("usurai").setup(opts)
    end,
  },
}
