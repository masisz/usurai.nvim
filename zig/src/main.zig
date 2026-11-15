const std = @import("std");
const search = @import("search.zig");

// Fuzzy matcher (core_fuzzy_*): its exports live in fuzzy.zig.
comptime {
    _ = @import("fuzzy.zig");
}

// ============================================================
// C ABI Exports for LuaJIT FFI (masisz.nvim) & Ruby Fiddle (rufio)
// ============================================================

/// Content search (Grep mode): returns handle (0 on failure). threads=0 uses CPU count.
export fn core_search_create(
    roots: [*]const u8,
    roots_len: usize,
    query: [*]const u8,
    query_len: usize,
    excluded: [*]const u8,
    excluded_len: usize,
    documents: [*]const u8,
    documents_len: usize,
    threads: u32,
    cache_handle: u64,
) u64 {
    const cache: ?*search.Cache = if (cache_handle == 0) null else @ptrFromInt(cache_handle);
    const s = search.Search.create(
        roots[0..roots_len],
        query[0..query_len],
        excluded[0..excluded_len],
        documents[0..documents_len],
        threads,
        cache,
    ) catch return 0;
    return @intFromPtr(s);
}

/// Fast parallel file scanner (fd replacement): walks roots and emits all non-excluded files.
export fn core_files_create(
    roots: [*]const u8,
    roots_len: usize,
    excluded: [*]const u8,
    excluded_len: usize,
    threads: u32,
) u64 {
    const s = search.Search.createFiles(
        roots[0..roots_len],
        excluded[0..excluded_len],
        threads,
    ) catch return 0;
    return @intFromPtr(s);
}

export fn core_search_state(handle: u64) u8 {
    if (handle == 0) return @intFromEnum(search.State.failed);
    const s: *search.Search = @ptrFromInt(handle);
    return @intFromEnum(s.getState());
}

/// Drain buffered records. Returned pointer is valid until next drain/destroy.
export fn core_search_drain(handle: u64, out_len: *usize) ?[*]const u8 {
    out_len.* = 0;
    if (handle == 0) return null;
    const s: *search.Search = @ptrFromInt(handle);
    const data = s.drain();
    out_len.* = data.len;
    return if (data.len == 0) null else data.ptr;
}

export fn core_search_skipped(handle: u64) u64 {
    if (handle == 0) return 0;
    const s: *search.Search = @ptrFromInt(handle);
    return s.skipped.load(.acquire);
}

export fn core_search_cancel(handle: u64) void {
    if (handle == 0) return;
    const s: *search.Search = @ptrFromInt(handle);
    s.cancel();
}

export fn core_search_destroy(handle: u64) void {
    if (handle == 0) return;
    const s: *search.Search = @ptrFromInt(handle);
    s.destroy();
}

/// Shared in-memory file content cache across searches.
export fn core_cache_create(max_bytes: u64) u64 {
    const cache = search.Cache.create(max_bytes) catch return 0;
    return @intFromPtr(cache);
}

export fn core_cache_bytes(handle: u64) u64 {
    if (handle == 0) return 0;
    const cache: *search.Cache = @ptrFromInt(handle);
    return cache.cachedBytes();
}

export fn core_cache_destroy(handle: u64) void {
    if (handle == 0) return;
    const cache: *search.Cache = @ptrFromInt(handle);
    cache.destroy();
}
