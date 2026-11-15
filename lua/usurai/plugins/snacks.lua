return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true },
    quickfile = { enabled = true },
    notifier = { enabled = true },
    picker = { enabled = true },
    explorer = { enabled = true },
    bufdelete = { enabled = true },
    statuscolumn = { enabled = false },
    words = { enabled = false },
    image = {
      formats = {
        "png",
        "jpg",
        "jpeg",
        "gif",
        "bmp",
        "webp",
        "tiff",
        "heic",
        "avif",
        "mp4",
        "mov",
        "avi",
        "mkv",
        "webm",
        "pdf",
      },
      force = false,
      doc = {
        enabled = true,
        inline = true,
        float = true,
        max_width = 80,
        max_height = 40,
        conceal = function(_, type)
          return type == "math"
        end,
      },
      img_dirs = { "img", "images", "assets", "static", "public", "media", "attachments" },
      wo = {
        wrap = false,
        number = false,
        relativenumber = false,
        cursorcolumn = false,
        signcolumn = "no",
        foldcolumn = "0",
        list = false,
        spell = false,
        statuscolumn = "",
      },
      cache = vim.fn.stdpath("cache") .. "/snacks/image",
      debug = {
        request = false,
        convert = false,
        placement = false,
      },
      env = {},
      icons = {
        math = "󰪚 ",
        chart = "󰄧 ",
        image = " ",
      },
      convert = {
        notify = true,
        mermaid = function()
          local theme = vim.o.background == "light" and "neutral" or "dark"
          return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-t", theme, "-s", "{scale}" }
        end,
        magick = {
          default = { "{src}[0]", "-scale", "1920x1080>" },
          vector = { "-density", 192, "{src}[0]" },
          math = { "-density", 192, "{src}[0]", "-trim" },
          pdf = { "-density", 192, "{src}[0]", "-background", "white", "-alpha", "remove", "-trim" },
        },
      },
      math = {
        enabled = true,
        typst = {
          tpl = [[
        #set page(width: auto, height: auto, margin: (x: 2pt, y: 2pt))
        #show math.equation.where(block: false): set text(top-edge: "bounds", bottom-edge: "bounds")
        #set text(size: 12pt, fill: rgb("${color}"))
        ${header}
        ${content}]],
        },
        latex = {
          font_size = "Large",
          packages = { "amsmath", "amssymb", "amsfonts", "amscd", "mathtools" },
          tpl = [[
        \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
        \usepackage{${packages}}
        \begin{document}
        ${header}
        { \${font_size} \selectfont
          \color[HTML]{${color}}
        ${content}}
        \end{document}]],
        },
      },
    },
  },
  keys = {
    -- Top Pickers & Explorer (powered by Zig Native FFI engine when available)
    { "<leader><space>", function() require("usurai.config.zig_search").pick_files() end, desc = "Find Files (Zig)" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>/", function() require("usurai.config.zig_search").pick_grep() end, desc = "Grep (Zig SIMD)" },
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },

    -- Find
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fc", function() require("usurai.config.zig_search").pick_files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
    { "<leader>fC", function() require("usurai.config.zig_search").pick_grep({ cwd = vim.fn.stdpath("config") }) end, desc = "Grep Config (Neovim)" },
    { "<leader>ff", function() require("usurai.config.zig_search").pick_files() end, desc = "Find Files (Zig)" },
    { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent Files" },

    -- Search
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
    { "<leader>sg", function() require("usurai.config.zig_search").pick_grep() end, desc = "Grep (Zig SIMD)" },
    { "<leader>sw", function() require("usurai.config.zig_search").pick_grep_word() end, desc = "Grep Word or Selection (Zig)", mode = { "n", "x" } },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume Last Picker" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo History" },

    -- Git View
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git File History" },

    -- Notifications
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss Notifications" },
  },
}
