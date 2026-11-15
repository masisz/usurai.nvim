return {
  -- 1. Surround actions (gsa, gsd, gsr)
  {
    "nvim-mini/mini.surround",
    keys = {
      { "gsa", desc = "Add Surrounding", mode = { "n", "x" } },
      { "gsd", desc = "Delete Surrounding" },
      { "gsf", desc = "Find Right Surrounding" },
      { "gsF", desc = "Find Left Surrounding" },
      { "gsh", desc = "Highlight Surrounding" },
      { "gsr", desc = "Replace Surrounding" },
      { "gsn", desc = "Update MiniSurround.config.n_lines" },
    },
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },

  -- 2. Auto-pairs
  {
    "nvim-mini/mini.pairs",
    event = "InsertEnter",
    opts = {
      modes = { insert = true, command = true, terminal = false },
      skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
      skip_ts = { "string" },
      skip_unbalanced = true,
      markdown = true,
    },
  },

  -- 3. Enhanced textobjects (a), if, etc.)
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    opts = {
      n_lines = 500,
    },
  },

  -- 4. Clipboard history manager
  {
    "atiladefreitas/lazyclip",
    config = function()
      require("lazyclip").setup({})
    end,
    keys = {
      { "<leader>Cw", desc = "Open Clipboard Manager" },
    },
  },
}
