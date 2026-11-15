return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
    },
    opts = function()
      local langs = require("usurai.config.langs").resolve()
      return {
        ensure_installed = langs.treesitter,
        highlight = { enable = true },
        indent = { enable = true },
        endwise = { enable = true },
      }
    end,
    config = function(_, opts)
      local ok_configs, ts_configs = pcall(require, "nvim-treesitter.configs")
      if ok_configs then
        ts_configs.setup(opts)
        return
      end

      local ok_ts, ts = pcall(require, "nvim-treesitter")
      if ok_ts and ts.setup then
        ts.setup({})
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("usurai_treesitter", { clear = true }),
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
}
