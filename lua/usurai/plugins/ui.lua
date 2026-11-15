local os_config = require("usurai.config.os")

-- Resolve wisteria.nvim (local ~/devs/public-git/wisteria.nvim if available, otherwise GitHub "masisz/wisteria.nvim")
local wisteria_spec = os_config.plugin_source("masisz/wisteria.nvim", "public-git", "wisteria.nvim")
wisteria_spec.name = "wisteria"
wisteria_spec.lazy = false
wisteria_spec.priority = 1000
wisteria_spec.opts = function()
  local cfg = vim.g.usurai or {}
  return vim.tbl_deep_extend("force", {
    style = "dark",
    transparent = true,
  }, cfg.wisteria or {})
end
wisteria_spec.config = function(_, opts)
  local ok, wisteria = pcall(require, "wisteria")
  if ok and wisteria.setup then
    wisteria.setup(opts)
  end
  local cfg = vim.g.usurai or {}
  pcall(vim.cmd.colorscheme, cfg.colorscheme or "wisteria")
end

return {
  -- 1. Colorscheme: wisteria.nvim
  wisteria_spec,

  -- 2. Icons (lightweight replacement for nvim-web-devicons)
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- 3. Statusline (lualine only, no bufferline or noice)
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-mini/mini.icons" },
    opts = function()
      local cfg = vim.g.usurai or {}
      local scheme = cfg.colorscheme or "wisteria"
      return {
        options = {
          theme = cfg.lualine_theme or (scheme == "wisteria" and "wisteria" or "auto"),
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = { statusline = { "snacks_dashboard" } },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            { "diagnostics" },
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { "filename", path = 1 },
          },
          lualine_x = {
            { "diff" },
            { "encoding" },
          },
          lualine_y = {
            { "progress", separator = " ", padding = { left = 1, right = 0 } },
            { "location", padding = { left = 0, right = 1 } },
          },
          lualine_z = {},
        },
      }
    end,
  },

  -- 4. Markdown inline rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-mini/mini.icons" },
    config = function()
      vim.opt_local.conceallevel = 2
      vim.opt_local.concealcursor = "nc"
      require("render-markdown").setup({})
    end,
  },

  -- 5. Git signs in gutter & hunk preview
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end
        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next Git Hunk")
        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Prev Git Hunk")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
        map("n", "<leader>ghb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>ghr", gs.reset_hunk, "Reset Hunk")
      end,
    },
  },
}
