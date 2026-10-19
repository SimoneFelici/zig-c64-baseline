// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const sdk_mod = @import("sdk/build.zig");

const SdkLibs = struct {
    c64: ?sdk_mod.Libs = null,
};

pub fn build(b: *std.Build) void {
    // llvm-mos-sdk git source — always required for headers, linker scripts, and platform libs.
    const sdk_dep = b.dependency("llvm-mos-sdk", .{});
    const sdk_src_raw = sdk_dep.builder.root.root_dir.path orelse ".";
    // Normalize separators for embedding in linker scripts and assembly (.incbin).
    const sdk_src = blk: {
        const buf = b.allocator.dupe(u8, sdk_src_raw) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };
    const optimize = b.standardOptimizeOption(.{});
    // ---- SDK build from source (llvm-mos-sdk git) ----
    const sdk_step = b.step("sdk-build", "Build llvm-mos-sdk platform libraries from source");

    var sdk_libs = SdkLibs{};

    for ([_]sdk_mod.Platform{
        .{ .name = "c64", .query = .{ .cpu_arch = .mos, .os_tag = .c64 } },
    }) |pd| {
        const libs = sdk_mod.buildPlatform(b, sdk_src_raw, pd, optimize);
        const dest = b.fmt("mos-platform/{s}/lib", .{pd.name});
        for ([3]*std.Build.Step.Compile{ libs.crt, libs.crt0, libs.c }) |lib| {
            sdk_step.dependOn(&b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        }
        if (std.mem.eql(u8, pd.name, "c64")) sdk_libs.c64 = libs;
    }

    // C64 hardware definitions (c64-zig).
    const c64_mod = b.dependency("c64_zig", .{}).module("c64");

    // Host tool: multi-format binary inspector (NES/PRG/A26/XEX/NEO).
    const bininfo = b.addExecutable(.{
        .name = "bininfo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/bininfo.zig"),
            .target = b.graph.host,
            .optimize = .safe,
        }),
    });
    b.installArtifact(bininfo);
    const check_outputs = b.step("check-outputs", "Inspect all built example binaries with bininfo");
    const run_bininfo = b.addRunArtifact(bininfo);
    check_outputs.dependOn(&run_bininfo.step);

    // Host tool: NES / SNES pack · unpack · disassemble.
    const romtool = b.addExecutable(.{
        .name = "romtool",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/romtool.zig"),
            .target = b.graph.host,
            .optimize = .safe,
        }),
    });
    b.installArtifact(romtool);
    const romtool_step = b.step("romtool", "Build romtool (NES/SNES/PRG pack·unpack·disasm)");
    romtool_step.dependOn(&romtool.step);

    // ---- C64 hello ----
    {
        const step = b.step("c64-hello", "Build C64 hello example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-hello", "c64/hello/hello.zig", false);
        exe.root_module.addImport("c64", c64_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 fibonacci ----
    {
        const step = b.step("c64-fibonacci", "Build C64 fibonacci example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "fibonacci", "c64/fibonacci/fibonacci.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fibonacci.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 plasma ----
    {
        const step = b.step("c64-plasma", "Build C64 plasma effect example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "plasma", "c64/plasma/plasma.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 benchmarks ----
    {
        const step = b.step("c64-bench-crc8", "Build C64 CRC-8/GSM-A benchmark (C64 Kernal)");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-crc8", "c64/bench-crc8/bench-crc8.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-crc8.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    {
        const step = b.step("c64-bench-crc16", "Build C64 CRC-16/XMODEM benchmark (C64 Kernal)");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-crc16", "c64/bench-crc16/bench-crc16.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-crc16.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    {
        const step = b.step("c64-bench-crc32", "Build C64 CRC-32/CKSUM benchmark (C64 Kernal)");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-crc32", "c64/bench-crc32/bench-crc32.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-crc32.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    {
        const step = b.step("c64-bench-aes256", "Build C64 AES-256-CBC benchmark");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-aes256", "c64/bench-aes256/bench-aes256.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-aes256.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    {
        const step = b.step("c64-bench-sieve", "Build C64 Sieve of Eratosthenes benchmark");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-sieve", "c64/bench-sieve/bench-sieve.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-sieve.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    {
        const step = b.step("c64-bench-pi", "Build C64 pi-digits benchmark (Spigot algorithm)");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-pi", "c64/bench-pi/bench-pi.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-pi.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    {
        const step = b.step("c64-bench-fact", "Build C64 factorial benchmark (1000 iterations)");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-bench-fact", "c64/bench-fact/bench-fact.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-bench-fact.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 picolibc-demo (string building via zig-picolibc) ----
    if (buildPicolibc(b, b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 }))) |pc| {
        const step = b.step("c64-picolibc-demo", "Build C64 picolibc string-building demo");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-picolibc-demo", "c64/picolibc-demo/picolibc-demo.zig", false);
        exe.root_module.linkLibrary(pc.lib);
        exe.root_module.addImport("picolibc", pc.string);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-picolibc-demo.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
}

fn addC64Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
    with_printf_flt: bool,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });

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

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
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
    if (with_printf_flt) exe.root_module.linkSystemLibrary("printf_flt", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addMosPanicImport(b: *std.Build, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) void {
    exe.root_module.addImport("mos_panic", b.createModule(.{
        .root_source_file = b.path("sdk/panic.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    }));
}

const PicoLibC = struct {
    lib: *std.Build.Step.Compile,
    string: *std.Build.Module,
};

fn buildPicolibc(b: *std.Build, target: std.Build.ResolvedTarget) ?PicoLibC {
    const dep = b.lazyDependency("picolibc", .{
        .target = target,
    }) orelse return null;
    return .{
        .lib = dep.artifact("picolibc"),
        .string = dep.module("string"),
    };
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
