local M = {}

M.is_mac = vim.fn.has("macunix") == 1
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
M.is_unix = vim.fn.has("unix") == 1

M.home = os.getenv(M.is_windows and "USERPROFILE" or "HOME") or vim.fn.expand("~")

function M.joinpath(...)
  return vim.fs.joinpath(...)
end

function M.dev_path(...)
  local root = os.getenv("NVIM_DEV_DIR") or M.joinpath(M.home, "devs")
  return M.joinpath(root, ...)
end

function M.executable(name)
  return vim.fn.executable(name) == 1
end

--- Resolve a plugin source: use local dev directory if available and enabled,
--- otherwise fall back to the public GitHub repository string.
---@param repo string GitHub "owner/name"
---@param ... string Subpaths under dev_path (e.g. "public-git", "wisteria.nvim")
---@return table
function M.plugin_source(repo, ...)
  local cfg = vim.g.usurai or {}
  if cfg.use_local_dev == true then
    local path = M.dev_path(...)
    if vim.uv.fs_stat(path) then
      return {
        dir = path,
        name = repo:match("([^/]+)$"),
      }
    end
  end
  return { repo }
end

return M
