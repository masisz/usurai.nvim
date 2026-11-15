return {
  -- 1. Mason (auto-installs only the LSP packages enabled in `vim.g.usurai.langs`)
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = function()
      local langs = require("usurai.config.langs").resolve()
      return {
        ensure_installed = langs.mason,
      }
    end,
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr.refresh(function()
        for _, tool in ipairs(opts.ensure_installed or {}) do
          local ok, p = pcall(mr.get_package, tool)
          if ok and not p:is_installed() then
            p:install()
          end
        end
      end)
    end,
  },

  -- 2. Minimal LSP Configuration (driven by `usurai.config.langs` + native `vim.lsp.completion`)
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    keys = {
      { "<leader>cl", "<Cmd>UsuraiLangs<CR>", desc = "Language Extras (UsuraiLangs)" },
    },
    config = function()
      local langs = require("usurai.config.langs").resolve()
      local enabled_server_names = vim.tbl_keys(langs.servers)

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("usurai_lsp_attach", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          -- Enable native Neovim 0.12+ LSP completion
          if client and client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
            vim.keymap.set("i", "<C-Space>", function()
              vim.lsp.completion.get()
            end, { buffer = event.buf, desc = "LSP: Trigger Completion" })
          end

          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          -- Code Navigation / View (powered by Snacks.picker when available)
          map("gd", function()
            if _G.Snacks then
              Snacks.picker.lsp_definitions()
            else
              vim.lsp.buf.definition()
            end
          end, "Goto Definition")

          map("gr", function()
            if _G.Snacks then
              Snacks.picker.lsp_references()
            else
              vim.lsp.buf.references()
            end
          end, "References")

          map("gI", function()
            if _G.Snacks then
              Snacks.picker.lsp_implementations()
            else
              vim.lsp.buf.implementation()
            end
          end, "Goto Implementation")

          map("gy", function()
            if _G.Snacks then
              Snacks.picker.lsp_type_definitions()
            else
              vim.lsp.buf.type_definition()
            end
          end, "Goto Type Definition")

          map("gD", vim.lsp.buf.declaration, "Goto Declaration")
          map("K", vim.lsp.buf.hover, "Hover Documentation")
          map("gK", vim.lsp.buf.signature_help, "Signature Help")

          map("<leader>ss", function()
            if _G.Snacks then
              Snacks.picker.lsp_symbols()
            else
              vim.lsp.buf.document_symbol()
            end
          end, "LSP Symbols")

          map("<leader>sS", function()
            if _G.Snacks then
              Snacks.picker.lsp_workspace_symbols()
            else
              vim.lsp.buf.workspace_symbol()
            end
          end, "LSP Workspace Symbols")

          -- Essential Code Edit actions
          map("<leader>cr", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code Action", { "n", "x" })
        end,
      })

      local capabilities = vim.lsp.protocol.make_client_capabilities()

      -- Only auto-enable servers that are explicitly enabled in `vim.g.usurai.langs`
      local ok_mlsp, mason_lspconfig = pcall(require, "mason-lspconfig")
      if ok_mlsp then
        mason_lspconfig.setup({
          automatic_enable = enabled_server_names,
        })
      end

      -- Configure each enabled server using Neovim 0.11+ vim.lsp.config or legacy lspconfig
      for server_name, server_opts in pairs(langs.servers) do
        server_opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server_opts.capabilities or {})
        if vim.lsp and vim.lsp.config then
          vim.lsp.config(server_name, server_opts)
          pcall(vim.lsp.enable, server_name)
        else
          local lspconfig = require("lspconfig")
          if lspconfig[server_name] then
            lspconfig[server_name].setup(server_opts)
          end
        end
      end
    end,
  },
}
