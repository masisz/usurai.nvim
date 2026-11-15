-- ============================================================================
-- Zig Native Search Engine (LuaJIT FFI binding for librufio_zig)
-- Shared core with `masisz/rufio` — replaces external `fd` and `rg`!
-- ============================================================================

local M = {}

local ffi_ok, ffi = pcall(require, "ffi")
local os_config = require("usurai.config.os")

local HEADER_SIZE = 25
local KIND_MATCH = 1
local STATE_SCANNING = 1

-- Default excluded binary extensions & build/cache directories (NUL-separated)
local DEFAULT_EXCLUDED = table.concat({
  -- Directories (prefixed with '/')
  "/.git",
  "/.hg",
  "/.svn",
  "/node_modules",
  "/.zig-cache",
  "/zig-out",
  "/target",
  "/dist",
  "/build",
  "/.next",
  "/.nuxt",
  "/.venv",
  "/venv",
  "/__pycache__",
  "/.DS_Store",
  -- Binary / archive / media extensions
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".bmp",
  ".pdf",
  ".zip",
  ".tar",
  ".gz",
  ".7z",
  ".rar",
  ".mp3",
  ".mp4",
  ".mov",
  ".wav",
  ".ogg",
  ".woff",
  ".woff2",
  ".ttf",
  ".otf",
  ".o",
  ".obj",
  ".so",
  ".dylib",
  ".dll",
  ".exe",
  ".bin",
  ".class",
  ".pyc",
  ".lock",
}, "\0")

local lib = nil
local cache_handle = 0
local build_in_progress = false

if ffi_ok then
  pcall(
    ffi.cdef,
    [[
    uint64_t core_search_create(
      const uint8_t *roots, size_t roots_len,
      const uint8_t *query, size_t query_len,
      const uint8_t *excluded, size_t excluded_len,
      const uint8_t *documents, size_t documents_len,
      uint32_t threads, uint64_t cache_handle
    );
    uint64_t core_files_create(
      const uint8_t *roots, size_t roots_len,
      const uint8_t *excluded, size_t excluded_len,
      uint32_t threads
    );
    uint8_t core_search_state(uint64_t handle);
    const uint8_t *core_search_drain(uint64_t handle, size_t *out_len);
    uint64_t core_search_skipped(uint64_t handle);
    void core_search_cancel(uint64_t handle);
    void core_search_destroy(uint64_t handle);
    uint64_t core_cache_create(uint64_t max_bytes);
    uint64_t core_cache_bytes(uint64_t handle);
    void core_cache_destroy(uint64_t handle);
  ]]
  )
end

local function lib_filename()
  if os_config.is_mac then
    return "librufio_zig.dylib"
  elseif os_config.is_windows then
    return "rufio_zig.dll"
  else
    return "librufio_zig.so"
  end
end

local function target_triple()
  local arch = ffi_ok and ffi.arch or ""
  if arch == "arm64" then
    arch = "aarch64"
  elseif arch == "x64" then
    arch = "x86_64"
  end

  local sys = "linux"
  if os_config.is_mac then
    sys = "macos"
  elseif os_config.is_windows then
    sys = "windows"
  end
  return arch .. "-" .. sys
end

--- Resolve the root directory of `usurai.nvim` whether installed via lazy.nvim,
--- loaded from a local dev directory, or cloned as ~/.config/nvim.
function M.plugin_root()
  local source = debug.getinfo(1, "S").source
  if source and source:sub(1, 1) == "@" then
    local this_dir = vim.fn.fnamemodify(source:sub(2), ":p:h")
    -- `this_dir` is `<root>/lua/usurai/config`
    local root = vim.fs.normalize(vim.fs.joinpath(this_dir, "../../.."))
    if vim.uv.fs_stat(root .. "/zig/build.zig") then
      return root
    end
  end

  local lazy_root = vim.fn.stdpath("data") .. "/lazy/usurai.nvim"
  if vim.uv.fs_stat(lazy_root .. "/zig/build.zig") then
    return lazy_root
  end

  return vim.fn.stdpath("config")
end

function M.zig_dir()
  return M.plugin_root() .. "/zig"
end

function M.local_lib_path()
  local zig_out = M.zig_dir() .. "/zig-out"
  local fname = lib_filename()
  local bin_path = zig_out .. "/bin/" .. fname
  if os_config.is_windows and vim.uv.fs_stat(bin_path) then
    return bin_path
  end
  return zig_out .. "/lib/" .. fname
end

function M.prebuilt_lib_path()
  return M.zig_dir() .. "/prebuilt/" .. target_triple() .. "/" .. lib_filename()
end

--- Resolve the shared library path:
--- 1. Locally built binary in `zig/zig-out/{lib,bin}/` (if built via `:UsuraiZigBuild`)
--- 2. Prebuilt binary bundled in `zig/prebuilt/<arch>-<os>/` (works out-of-the-box after `git clone`)
function M.lib_path()
  local local_path = M.local_lib_path()
  if vim.uv.fs_stat(local_path) then
    return local_path
  end
  local prebuilt_path = M.prebuilt_lib_path()
  if vim.uv.fs_stat(prebuilt_path) then
    return prebuilt_path
  end
  return prebuilt_path
end

--- Load the compiled Zig shared library via LuaJIT FFI
function M.load()
  if lib then
    return lib
  end
  if not ffi_ok then
    return nil
  end

  local path = M.lib_path()
  if not vim.uv.fs_stat(path) then
    return nil
  end

  local ok, loaded = pcall(ffi.load, path)
  if not ok then
    return nil
  end

  lib = loaded
  if cache_handle == 0 then
    -- Create 256MB persistent in-memory file cache for instant Live Grep
    cache_handle = lib.core_cache_create(256 * 1024 * 1024)
  end
  return lib
end

function M.is_available()
  local cfg = vim.g.usurai or {}
  if cfg.zig_search == false then
    return false
  end
  return M.load() ~= nil
end

--- Build the Zig library asynchronously using `zig build -Doptimize=ReleaseFast`
function M.build(notify_on_done)
  if build_in_progress then
    return
  end
  if vim.fn.executable("zig") == 0 then
    if notify_on_done then
      vim.notify("`zig` compiler not found in PATH.", vim.log.levels.WARN)
    end
    return
  end

  local zig_dir = M.zig_dir()
  if not vim.uv.fs_stat(zig_dir .. "/build.zig") then
    return
  end

  build_in_progress = true
  if notify_on_done then
    vim.notify("Building Zig native search engine (librufio_zig)...", vim.log.levels.INFO)
  end

  vim.fn.jobstart({ "zig", "build", "-Doptimize=ReleaseFast" }, {
    cwd = zig_dir,
    on_exit = function(_, code)
      build_in_progress = false
      if code == 0 then
        lib = nil
        M.load()
        if notify_on_done then
          vim.notify("Zig native search engine built and loaded!", vim.log.levels.INFO)
        end
      elseif notify_on_done then
        vim.notify("Failed to build Zig search engine (exit code " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
end

-- Auto-read little-endian integers from uint8_t pointer
local function read_u32(ptr, offset)
  return ptr[offset]
    + ptr[offset + 1] * 0x100
    + ptr[offset + 2] * 0x10000
    + ptr[offset + 3] * 0x1000000
end

local function read_u64_low(ptr, offset)
  return read_u32(ptr, offset) + read_u32(ptr, offset + 4) * 0x100000000
end

--- Parse drained binary records from `core_search_drain`
local function drain_records(engine, handle, out_len_buf, on_record)
  local ptr = engine.core_search_drain(handle, out_len_buf)
  local total_len = tonumber(out_len_buf[0]) or 0
  if ptr == nil or total_len == 0 then
    return 0
  end

  local pos = 0
  local count = 0
  while pos + HEADER_SIZE <= total_len do
    local kind = ptr[pos]
    local line = read_u64_low(ptr, pos + 5)
    local col_offset = read_u32(ptr, pos + 13)
    local path_len = read_u32(ptr, pos + 17)
    local extra_len = read_u32(ptr, pos + 21)
    local payload_start = pos + HEADER_SIZE
    local next_pos = payload_start + path_len + extra_len
    if next_pos > total_len then
      break
    end

    if kind == KIND_MATCH then
      local path = ffi.string(ptr + payload_start, path_len)
      local extra = extra_len > 0 and ffi.string(ptr + payload_start + path_len, extra_len) or ""
      count = count + 1
      if on_record(path, line, col_offset, extra) == false then
        return count, true
      end
    end

    pos = next_pos
  end
  return count, false
end

--- Scan files in `cwd` using the Zig parallel walker (replaces `fd`)
---@param cwd? string
---@param max_items? number
function M.scan_files(cwd, max_items)
  local engine = M.load()
  if not engine then
    return nil
  end

  local root = cwd or vim.fn.getcwd()
  max_items = max_items or 25000

  local handle = engine.core_files_create(root, #root, DEFAULT_EXCLUDED, #DEFAULT_EXCLUDED, 0)
  if handle == 0 then
    return {}
  end

  local out_len_buf = ffi.new("size_t[1]")
  local items = {}
  local prefix = root .. "/"
  local prefix_len = #prefix

  local function collect()
    local _, stopped = drain_records(engine, handle, out_len_buf, function(path)
      local rel = path
      if path:sub(1, prefix_len) == prefix then
        rel = path:sub(prefix_len + 1)
      end
      items[#items + 1] = {
        file = rel,
        text = rel,
      }
      if #items >= max_items then
        engine.core_search_cancel(handle)
        return false
      end
    end)
    return stopped
  end

  while true do
    local state = engine.core_search_state(handle)
    if collect() then
      break
    end
    if state ~= STATE_SCANNING then
      collect()
      break
    end
    vim.uv.sleep(1)
  end

  engine.core_search_destroy(handle)
  return items
end

--- Search file contents in `cwd` using Zig SIMD + in-memory cache (replaces `rg`)
---@param query string
---@param cwd? string
---@param max_items? number
function M.search_content(query, cwd, max_items)
  local engine = M.load()
  if not engine then
    return nil
  end
  if not query or #query == 0 then
    return {}
  end

  local root = cwd or vim.fn.getcwd()
  max_items = max_items or 5000

  local handle = engine.core_search_create(
    root,
    #root,
    query,
    #query,
    DEFAULT_EXCLUDED,
    #DEFAULT_EXCLUDED,
    "",
    0,
    0,
    cache_handle
  )
  if handle == 0 then
    return {}
  end

  local out_len_buf = ffi.new("size_t[1]")
  local items = {}
  local prefix = root .. "/"
  local prefix_len = #prefix
  local q_len = #query

  local function collect()
    local _, stopped = drain_records(engine, handle, out_len_buf, function(path, line, col_offset, extra)
      local rel = path
      if path:sub(1, prefix_len) == prefix then
        rel = path:sub(prefix_len + 1)
      end
      local clean_line = extra:gsub("[\r\n]+$", "")
      items[#items + 1] = {
        file = rel,
        pos = { line, col_offset },
        end_pos = { line, col_offset + q_len },
        line = clean_line,
        text = string.format("%s:%d:%d:%s", rel, line, col_offset + 1, clean_line),
      }
      if #items >= max_items then
        engine.core_search_cancel(handle)
        return false
      end
    end)
    return stopped
  end

  while true do
    local state = engine.core_search_state(handle)
    if collect() then
      break
    end
    if state ~= STATE_SCANNING then
      collect()
      break
    end
    vim.uv.sleep(1)
  end

  engine.core_search_destroy(handle)
  return items
end

--- Open Snacks.picker for Files powered by Zig engine (falls back to Snacks.picker.files)
function M.pick_files(opts)
  opts = opts or {}
  if not M.is_available() or not (_G.Snacks and Snacks.picker) then
    return Snacks.picker.files(opts)
  end

  local cwd = opts.cwd or vim.fn.getcwd()
  return Snacks.picker.pick(vim.tbl_extend("force", {
    source = "files",
    title = "Find Files (Zig Native)",
    cwd = cwd,
    format = "file",
    preview = "file",
    finder = function()
      return M.scan_files(cwd) or {}
    end,
  }, opts))
end

--- Open Snacks.picker for Live Grep powered by Zig SIMD + RAM Cache (falls back to Snacks.picker.grep)
function M.pick_grep(opts)
  opts = opts or {}
  if not M.is_available() or not (_G.Snacks and Snacks.picker) then
    return Snacks.picker.grep(opts)
  end

  local cwd = opts.cwd or vim.fn.getcwd()
  return Snacks.picker.pick(vim.tbl_extend("force", {
    source = "grep",
    title = "Grep (Zig SIMD + Cache)",
    cwd = cwd,
    live = true,
    supports_empty = false,
    format = "file",
    preview = "file",
    finder = function(_, ctx)
      local search = ctx and ctx.filter and ctx.filter.search or opts.search or ""
      if search == "" then
        return {}
      end
      return M.search_content(search, cwd) or {}
    end,
  }, opts))
end

--- Grep word under cursor or visual selection powered by Zig engine
function M.pick_grep_word(opts)
  opts = opts or {}
  if not M.is_available() or not (_G.Snacks and Snacks.picker) then
    return Snacks.picker.grep_word(opts)
  end

  local word = opts.search
  if not word then
    local mode = vim.fn.mode()
    if mode:find("[vV\22]") then
      local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
      word = lines[1] or ""
    else
      word = vim.fn.expand("<cword>")
    end
  end

  return M.pick_grep(vim.tbl_extend("force", {
    title = "Grep Word: " .. word .. " (Zig SIMD)",
    search = word,
    live = false,
  }, opts))
end

--- Show Zig Search Engine & RAM Cache status
function M.status()
  local engine = M.load()
  if not engine then
    vim.notify("Zig Search Engine: not loaded (run :UsuraiZigBuild)", vim.log.levels.WARN)
    return
  end
  local bytes = tonumber(engine.core_cache_bytes(cache_handle)) or 0
  local mb = bytes / (1024 * 1024)
  vim.notify(
    string.format("Zig Search Engine: ACTIVE (%s) | RAM Cache: %.2f MB / 256 MB", M.lib_path(), mb),
    vim.log.levels.INFO
  )
end

if vim.fn.exists(":UsuraiZigBuild") == 0 then
  vim.api.nvim_create_user_command("UsuraiZigBuild", function()
    M.build(true)
  end, { desc = "Build Zig native search engine (librufio_zig)" })
end

if vim.fn.exists(":UsuraiZigStatus") == 0 then
  vim.api.nvim_create_user_command("UsuraiZigStatus", function()
    M.status()
  end, { desc = "Show Zig native search engine and cache status" })
end

-- Auto-build in background on first startup if library is missing and `zig` is installed
if not vim.uv.fs_stat(M.lib_path()) and vim.fn.executable("zig") == 1 then
  vim.schedule(function()
    M.build(false)
  end)
end

return M
