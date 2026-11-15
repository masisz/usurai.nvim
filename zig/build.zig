const std = @import("std");

// NOTE: `src/search.zig`, `src/os.zig`, `src/search_test.zig`, `src/fuzzy.zig`, and
// `src/fuzzy_test.zig` are managed in
// `rufio/lib_zig/rufio_native/src/` as the Single Source of Truth.
// Run `rake native:sync_nvim` (or `make -C lib_zig/rufio_native sync-nvim`) in `rufio` to sync.

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared library loaded directly by Neovim LuaJIT FFI (and Ruby Fiddle in rufio)
    const lib = b.addLibrary(.{
        .name = "rufio_zig",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .strip = true,
        }),
    });
    b.installArtifact(lib);

    // Prebuild step: cross-compile for all major platforms into `zig/prebuilt/<arch>-<os>/`
    const prebuild_step = b.step(
        "prebuild",
        "Cross-compile prebuilt shared libraries for all major OS/arch targets into zig/prebuilt/",
    );
    const PrebuildTarget = struct {
        dir: []const u8,
        query: std.Target.Query,
        filename: []const u8,
    };
    const prebuild_targets = [_]PrebuildTarget{
        .{
            .dir = "aarch64-macos",
            .query = .{ .cpu_arch = .aarch64, .os_tag = .macos },
            .filename = "librufio_zig.dylib",
        },
        .{
            .dir = "x86_64-macos",
            .query = .{ .cpu_arch = .x86_64, .os_tag = .macos },
            .filename = "librufio_zig.dylib",
        },
        .{
            .dir = "x86_64-linux",
            .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
            .filename = "librufio_zig.so",
        },
        .{
            .dir = "aarch64-linux",
            .query = .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
            .filename = "librufio_zig.so",
        },
        .{
            .dir = "x86_64-windows",
            .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
            .filename = "rufio_zig.dll",
        },
        .{
            .dir = "aarch64-windows",
            .query = .{ .cpu_arch = .aarch64, .os_tag = .windows, .abi = .gnu },
            .filename = "rufio_zig.dll",
        },
    };

    for (prebuild_targets) |pt| {
        const cross_lib = b.addLibrary(.{
            .name = "rufio_zig",
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(pt.query),
                .optimize = .ReleaseFast,
                .link_libc = true,
                .strip = true,
            }),
        });
        const install_file = b.addInstallFileWithDir(
            cross_lib.getEmittedBin(),
            .{ .custom = "../prebuilt" },
            b.fmt("{s}/{s}", .{ pt.dir, pt.filename }),
        );
        prebuild_step.dependOn(&install_file.step);
    }

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/search_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const test_step = b.step("test", "Run unit tests for the Zig search and fuzzy engines");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const fuzzy_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fuzzy_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(fuzzy_tests).step);
}
