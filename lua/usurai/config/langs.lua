-- ============================================================================
-- usurai.nvim Language Extras Catalog (Zero-Bloat Language Packs)
-- Each pack defines only Tree-sitter parsers + minimal LSP configuration.
-- Toggle languages via:
--   1. `{ "masisz/usurai.nvim", opts = { langs = { rust = true } } }`
--   2. `{ import = "usurai.plugins.extras.lang.rust" }`
--   3. `vim.g.usurai.langs` in `lua/config/options.lua`
-- ============================================================================

local M = {}

---@class UsuraiLangPack
---@field desc string
---@field treesitter? string[]
---@field mason? string[]
---@field servers? table<string, table>

---@type table<string, UsuraiLangPack>
M.catalog = {
  lua = {
    desc = "Lua (lua_ls)",
    treesitter = { "lua", "luadoc" },
    mason = { "lua-language-server" },
    servers = {
      lua_ls = {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            codeLens = { enable = false },
            completion = { callSnippet = "Replace" },
            diagnostics = { globals = { "vim", "Snacks" } },
          },
        },
      },
    },
  },

  python = {
    desc = "Python (pyright)",
    treesitter = { "python" },
    mason = { "pyright" },
    servers = {
      pyright = {},
    },
  },

  typescript = {
    desc = "TypeScript / JavaScript (vtsls)",
    treesitter = { "typescript", "tsx", "javascript" },
    mason = { "vtsls" },
    servers = {
      vtsls = {},
    },
  },

  web = {
    desc = "HTML / CSS / Vue / Svelte / Emmet",
    treesitter = { "html", "css", "scss", "vue", "svelte" },
    mason = { "emmet-ls", "html-lsp", "css-lsp" },
    servers = {
      emmet_ls = {},
      html = {},
      cssls = {},
    },
  },

  data = {
    desc = "JSON / YAML / TOML",
    treesitter = { "json", "yaml", "toml" },
    mason = { "json-lsp", "yaml-language-server", "taplo" },
    servers = {
      jsonls = {},
      yamlls = {},
      taplo = {},
    },
  },

  markdown = {
    desc = "Markdown / LaTeX / Typst (marksman)",
    treesitter = { "markdown", "markdown_inline", "latex", "typst" },
    mason = { "marksman" },
    servers = {
      marksman = {},
    },
  },

  rust = {
    desc = "Rust (rust_analyzer)",
    treesitter = { "rust" },
    mason = { "rust-analyzer" },
    servers = {
      rust_analyzer = {},
    },
  },

  go = {
    desc = "Go (gopls)",
    treesitter = { "go", "gomod", "gosum" },
    mason = { "gopls" },
    servers = {
      gopls = {},
    },
  },

  ruby = {
    desc = "Ruby (ruby_lsp)",
    treesitter = { "ruby" },
    mason = { "ruby-lsp" },
    servers = {
      ruby_lsp = {},
    },
  },

  cpp = {
    desc = "C / C++ / CMake / Unreal Engine (clangd)",
    treesitter = { "c", "cpp", "cmake" },
    mason = { "clangd" },
    servers = {
      clangd = {
        root_dir = function(bufnr, on_dir)
          local markers = {
            ["compile_commands.json"] = true,
            ["compile_flags.txt"] = true,
            [".clangd"] = true,
            [".clang-tidy"] = true,
            [".clang-format"] = true,
            [".git"] = true,
          }
          local root = vim.fs.root(bufnr, function(name)
            return markers[name] or name:match("%.uproject$") ~= nil or name:match("%.uplugin$") ~= nil
          end)
          if root then
            on_dir(root)
          end
        end,
      },
    },
  },

  csharp = {
    desc = "C# / .NET / Razor (omnisharp)",
    treesitter = { "c_sharp", "razor" },
    mason = { "omnisharp" },
    servers = {
      omnisharp = {},
    },
  },

  godot = {
    desc = "Godot Engine (gdscript)",
    treesitter = { "gdscript", "godot_resource" },
    mason = {},
    servers = {
      gdscript = {},
    },
  },

  zig = {
    desc = "Zig (zls)",
    treesitter = { "zig" },
    mason = { "zls" },
    servers = {
      zls = {},
    },
  },

  sql = {
    desc = "SQL (sqlls + sql treesitter)",
    treesitter = { "sql" },
    mason = { "sqlls" },
    servers = {
      sqlls = {},
    },
  },

  java = {
    desc = "Java (jdtls)",
    treesitter = { "java" },
    mason = { "jdtls" },
    servers = {
      jdtls = {},
    },
  },

  r = {
    desc = "R (r_language_server)",
    treesitter = { "r" },
    mason = { "r-languageserver" },
    servers = {
      r_language_server = {},
    },
  },

  shell = {
    desc = "Bash / Shell (bashls + shellcheck)",
    treesitter = { "bash" },
    mason = { "bash-language-server", "shellcheck" },
    servers = {
      bashls = {},
    },
  },

  pwsh = {
    desc = "PowerShell (powershell_es)",
    treesitter = { "powershell" },
    mason = { "powershell-editor-services" },
    servers = {
      powershell_es = {},
    },
  },

  powershell = {
    desc = "PowerShell (alias for pwsh)",
    treesitter = { "powershell" },
    mason = { "powershell-editor-services" },
    servers = {
      powershell_es = {},
    },
  },

  docker = {
    desc = "Dockerfile & Compose (dockerls + docker_compose_language_service)",
    treesitter = { "dockerfile" },
    mason = { "dockerfile-language-server", "docker-compose-language-service" },
    servers = {
      dockerls = {},
      docker_compose_language_service = {},
    },
  },
}

-- Base Tree-sitter parsers always installed
local base_treesitter = {
  "bash",
  "query",
  "regex",
  "vim",
  "vimdoc",
}

local function list_add_unique(list, items)
  for _, item in ipairs(items or {}) do
    if not vim.tbl_contains(list, item) then
      table.insert(list, item)
    end
  end
end

--- Enable a language pack programmatically (used by `usurai.plugins.extras.lang.*`)
---@param lang_name string
function M.enable(lang_name)
  require("usurai.config").pre_init()
  vim.g.usurai = vim.g.usurai or {}
  vim.g.usurai.langs = vim.g.usurai.langs or {}
  vim.g.usurai.langs[lang_name] = true
  return {}
end

--- Resolve enabled language packs from `vim.g.usurai.langs`
function M.resolve()
  require("usurai.config").pre_init()
  local cfg = vim.g.usurai or {}
  local enabled_langs = cfg.langs or {}

  local ts_parsers = vim.deepcopy(base_treesitter)
  local mason_pkgs = {}
  local lsp_servers = {}

  for lang_name, is_enabled in pairs(enabled_langs) do
    if is_enabled then
      local pack = M.catalog[lang_name]
      if pack then
        list_add_unique(ts_parsers, pack.treesitter)
        list_add_unique(mason_pkgs, pack.mason)
        for srv, srv_opts in pairs(pack.servers or {}) do
          lsp_servers[srv] = vim.tbl_deep_extend("force", lsp_servers[srv] or {}, srv_opts)
        end
      end
    end
  end

  -- Allow user to pass custom ad-hoc LSP servers via `vim.g.usurai.custom_servers`
  if type(cfg.custom_servers) == "table" then
    for srv, srv_opts in pairs(cfg.custom_servers) do
      lsp_servers[srv] = vim.tbl_deep_extend("force", lsp_servers[srv] or {}, srv_opts)
    end
  end

  table.sort(ts_parsers)
  table.sort(mason_pkgs)

  return {
    treesitter = ts_parsers,
    mason = mason_pkgs,
    servers = lsp_servers,
  }
end

local function find_user_config_file()
  local config_dir = vim.fn.stdpath("config")
  local candidates = {
    config_dir .. "/lua/config/options.lua",
    config_dir .. "/lua/config/lazy.lua",
    config_dir .. "/init.lua",
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      return path
    end
  end
  return candidates[3]
end

--- Open interactive Snacks picker showing all available Language Packs (:UsuraiLangs)
function M.open_picker()
  local cfg = vim.g.usurai or {}
  local enabled_langs = cfg.langs or {}
  local items = {}
  local target_file = find_user_config_file()

  local names = vim.tbl_keys(M.catalog)
  table.sort(names)

  for _, name in ipairs(names) do
    local pack = M.catalog[name]
    local enabled = enabled_langs[name] == true
    local srvs = table.concat(vim.tbl_keys(pack.servers or {}), ", ")
    local status = enabled and "[x]" or "[ ]"
    table.insert(items, {
      text = string.format("%s %-12s  %s  (LSP: %s)", status, name, pack.desc, srvs),
      lang = name,
      enabled = enabled,
      file = target_file,
    })
  end

  if _G.Snacks and Snacks.picker then
    Snacks.picker.pick({
      title = "usurai.nvim Language Extras (Press <CR> to open config)",
      items = items,
      format = "text",
      confirm = function(picker, item)
        picker:close()
        if item and item.file then
          vim.cmd("edit " .. vim.fn.fnameescape(item.file))
          vim.fn.search("langs%s*=")
          if item.lang then
            vim.fn.search("\\<" .. item.lang .. "\\>")
          end
        end
      end,
    })
  else
    vim.cmd("edit " .. vim.fn.fnameescape(target_file))
  end
end

if vim.fn.exists(":UsuraiLangs") == 0 then
  vim.api.nvim_create_user_command("UsuraiLangs", function()
    M.open_picker()
  end, { desc = "Show usurai.nvim language extras status" })
end

return M
