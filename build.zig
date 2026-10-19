// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const sdk_mod = @import("sdk/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });
    const optimize = b.standardOptimizeOption(.{});

    // llvm-mos-sdk git source — always required for headers, linker scripts, and platform libs.
    const sdk_dep = b.dependency("llvm-mos-sdk", .{});
    const sdk_src_raw = sdk_dep.builder.root.root_dir.path orelse ".";
    // Normalize separators for embedding in linker scripts and assembly (.incbin).
    const sdk_src = blk: {
        const buf = b.allocator.dupe(u8, sdk_src_raw) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };

    // ---- SDK build from source (llvm-mos-sdk git) ----
    const sdk_libs = sdk_mod.buildPlatform(b, sdk_src_raw, .{
        .name = "c64",
        .query = .{ .cpu_arch = .mos, .os_tag = .c64 },
    }, optimize);
    const sdk_step = b.step("sdk-build", "Build llvm-mos-sdk platform libraries from source");
    for ([3]*std.Build.Step.Compile{ sdk_libs.crt, sdk_libs.crt0, sdk_libs.c }) |lib| {
        sdk_step.dependOn(&b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = "mos-platform/c64/lib" } } }).step);
    }

    // C64 hardware definitions (c64-zig).
    const c64_mod = b.dependency("c64_zig", .{}).module("c64");

    const mos_panic_mod = b.createModule(.{
        .root_source_file = b.path("sdk/panic.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .off,
    });

    const exe = b.addExecutable(.{
        .name = "baseline",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .sanitize_c = .off,
            .imports = &.{
                .{ .name = "c64", .module = c64_mod },
                .{ .name = "mos_panic", .module = mos_panic_mod },
            },
        }),
    });
    linkC64(b, exe, sdk_dep, sdk_src, sdk_libs);

    const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "main.prg" });
    b.getInstallStep().dependOn(&install.step);
}

/// Links an executable as a C64 .prg using the llvm-mos-sdk runtime.
fn linkC64(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
) void {
    const wf = b.addWriteFiles();
    const libc_txt = addLibcTxt(b, wf, sdk_src, "c64");
    // Inline c64/link.ld + commodore/commodore.ld, replacing INPUT() directives with
    // addAssemblyFile calls below (lld INPUT() doesn't search -L paths for .o files).
    const wrapper_ld = wf.add("c64-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/c64");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\__basic_zp_start = 0x0002;
        \\__basic_zp_end = 0x0090;
        \\MEMORY {{ ram (rw) : ORIGIN = 0x0801, LENGTH = 0xC7FF }}
        \\__rc0 = __basic_zp_start;
        \\INCLUDE "imag-regs.ld"
        \\__basic_zp_size = __basic_zp_end - __basic_zp_start;
        \\MEMORY {{ zp : ORIGIN = __rc31 + 1, LENGTH = __basic_zp_end - (__rc31 + 1) }}
        \\REGION_ALIAS("c_readonly", ram)
        \\REGION_ALIAS("c_writeable", ram)
        \\SECTIONS {{ .basic_header : {{ *(.basic_header) }} INCLUDE "c.ld" }}
        \\__stack = 0xD000;
        \\OUTPUT_FORMAT {{ SHORT(ORIGIN(ram)) TRIM(ram) }}
    , .{ sdk_src, sdk_src, sdk_src }));

    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.forceUndefinedSymbol("puts");
    // basic-header.S and unmap-basic.S replace INPUT(basic-header.o) / INPUT(unmap-basic.o).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/basic-header.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/unmap-basic.S"));
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.printf) |libprintf| exe.root_module.linkLibrary(libprintf);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
}

fn addLibcTxt(b: *std.Build, wf: *std.Build.Step.WriteFile, sdk_src: []const u8, plat: []const u8) std.Build.LazyPath {
    return wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/{s}\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/{s}\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\ndarwin_sdk_dir=\n",
        .{ sdk_src, plat, sdk_src, sdk_src, plat },
    ));
}
