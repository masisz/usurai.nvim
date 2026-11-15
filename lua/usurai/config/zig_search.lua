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
    uint64_t core_fuzzy_create(void);
    int32_t core_fuzzy_add(uint64_t handle, const uint8_t *data, size_t length);
    int32_t core_fuzzy_query(uint64_t handle, const uint8_t *data, size_t length, uint32_t limit);
    const uint8_t *core_fuzzy_results(uint64_t handle, size_t *length);
    void core_fuzzy_destroy(uint64_t handle);
  ]]
  )
end

-- Limits enforced by fuzzy.zig (MAX_QUERY_BYTES / MAX_CANDIDATE_BYTES / MAX_RESULTS)
local FUZZY_MAX_QUERY_BYTES = 1024
local FUZZY_MAX_CANDIDATE_BYTES = 65536
local FUZZY_MAX_RESULTS = 10000

--- Separator between the grep pattern and the fuzzy filter in `pick_grep`
--- (two spaces, so a single space can still be grepped literally).
M.FUZZY_SEPARATOR = "  "

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

--- Split a grep prompt into the literal grep pattern and the fuzzy filter.
--- `"render  fzsess"` -> `"render", "fzsess"`; without the separator the filter is `""`.
---@param input string
---@return string pattern, string filter
function M.split_query(input)
  local at = input:find(M.FUZZY_SEPARATOR, 1, true)
  if not at then
    return input, ""
  end
  local filter = input:sub(at + #M.FUZZY_SEPARATOR):gsub("^%s+", ""):gsub("%s+$", "")
  return input:sub(1, at - 1), filter
end

--- Replace bytes that are not valid UTF-8 (and NUL) with "?", since fuzzy.zig rejects them.
local function sanitize_utf8(text)
  if not text:find("[%z\128-\255]") then
    return text
  end
  local out = {}
  local i, n = 1, #text
  while i <= n do
    local b = text:byte(i)
    local len = b < 0x80 and 1 or b >= 0xC2 and b <= 0xDF and 2 or b >= 0xE0 and b <= 0xEF and 3
      or b >= 0xF0 and b <= 0xF4 and 4 or 0
    local ok = len > 0 and i + len - 1 <= n
    if ok and len > 1 then
      for k = i + 1, i + len - 1 do
        local c = text:byte(k)
        if c < 0x80 or c > 0xBF then
          ok = false
          break
        end
      end
      if ok then
        local b2 = text:byte(i + 1)
        -- overlong / surrogate / out-of-range sequences
        if
          (b == 0xE0 and b2 < 0xA0)
          or (b == 0xED and b2 > 0x9F)
          or (b == 0xF0 and b2 < 0x90)
          or (b == 0xF4 and b2 > 0x8F)
        then
          ok = false
        end
      end
    end
    if ok and b ~= 0 then
      out[#out + 1] = text:sub(i, i + len - 1)
      i = i + len
    else
      out[#out + 1] = "?"
      i = i + 1
    end
  end
  return table.concat(out)
end

--- Prepare a string for fuzzy.zig: valid UTF-8, no NUL, at most `max_bytes` bytes
--- (cut on a character boundary).
local function fuzzy_text(text, max_bytes)
  text = sanitize_utf8(text)
  if #text > max_bytes then
    local cut = max_bytes
    while cut > 0 and text:byte(cut + 1) and text:byte(cut + 1) >= 0x80 and text:byte(cut + 1) <= 0xBF do
      cut = cut - 1
    end
    text = text:sub(1, cut)
  end
  return text
end

--- Fuzzy-filter `items` with the Zig engine shared with rufio (fuzzy.zig).
--- Each candidate is `item[key]` (default `item.text`). Returns the matching items,
--- best score first, or nil when the native library is unavailable.
---@param items table[]
---@param query string
---@param opts? { key?: string, limit?: number }
---@return table[]?
function M.fuzzy_filter(items, query, opts)
  opts = opts or {}
  local engine = M.load()
  if not engine then
    return nil
  end
  query = fuzzy_text(query or "", FUZZY_MAX_QUERY_BYTES)
  if query == "" or #items == 0 then
    return items
  end
  local key = opts.key or "text"
  local limit = math.min(opts.limit or #items, FUZZY_MAX_RESULTS)

  local handle = engine.core_fuzzy_create()
  if handle == 0 then
    return nil
  end

  local ok, result = pcall(function()
    local texts = {}
    for i, item in ipairs(items) do
      texts[i] = fuzzy_text(tostring(item[key] or ""), FUZZY_MAX_CANDIDATE_BYTES)
    end
    local packed = table.concat(texts, "\0") .. "\0"
    if engine.core_fuzzy_add(handle, packed, #packed) ~= 0 then
      return nil
    end
    if engine.core_fuzzy_query(handle, query, #query, limit) ~= 0 then
      return nil
    end

    local len_buf = ffi.new("size_t[1]")
    local ptr = engine.core_fuzzy_results(handle, len_buf)
    local total_len = tonumber(len_buf[0]) or 0
    if ptr == nil or total_len < 12 then
      return {}
    end
    -- Layout: u64 total, u32 count, then per match: u64 id, i64 score, u32 n, n * u32 byte offsets
    local count = read_u32(ptr, 8)
    local pos = 12
    local out = {}
    for _ = 1, count do
      if pos + 20 > total_len then
        break
      end
      local id = read_u64_low(ptr, pos)
      local n = read_u32(ptr, pos + 16)
      out[#out + 1] = items[id + 1]
      pos = pos + 20 + n * 4
    end
    return out
  end)

  engine.core_fuzzy_destroy(handle)
  if not ok then
    return nil
  end
  return result
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

--- Grep with the Zig engine, then fuzzy-filter the hits when the prompt contains
--- `M.FUZZY_SEPARATOR` (`"pattern  filter"`). The filter matches `path:line:col:text`.
---@param input string
---@param cwd? string
---@param max_items? number
function M.search_content_fuzzy(input, cwd, max_items)
  local pattern, filter = M.split_query(input or "")
  if pattern == "" then
    return {}
  end
  local items = M.search_content(pattern, cwd, max_items)
  if not items or filter == "" then
    return items
  end
  return M.fuzzy_filter(items, filter) or items
end

--- Open Snacks.picker for Live Grep powered by Zig SIMD + RAM Cache (falls back to Snacks.picker.grep).
--- Type `pattern  filter` (two spaces) to fuzzy-filter the grep hits by path and line.
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
      return M.search_content_fuzzy(search, cwd) or {}
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
