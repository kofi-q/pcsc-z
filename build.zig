const base = @import("base");
const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const steps = Steps{
        .check = b.step("check", "Get compile-time diagnostics"),
        .ci = b.step("ci", "Run main CI steps"),
        .docs = b.step("docs", "Generate documentation"),
        .e2e = b.step("e2e", "Run E2E test app"),
        .fmt = b.step("fmt", "Format/lint source files"),
        .macos_deps = b.step("macos:deps", "Update MacOS PCSC Framework deps"),
        .tests = b.step("test", "Run unit tests"),
    };

    const mod_base = modBase(b, mode, target);
    const mod_pcsc = b.addModule("pcsc", .{
        .imports = &.{
            .{ .name = "base", .module = mod_base },
        },
        .link_libc = target.result.os.tag == .linux,
        .optimize = mode,
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    linkPcsc(b, mod_pcsc);

    addDepsUpdate(b, &steps);
    addDocs(b, &steps, mod_pcsc);
    addE2e(b, &steps, mode, target, mod_base, mod_pcsc);
    addFmt(b, &steps);
    addTests(b, &steps, mod_pcsc);
    addExamples(b, mode, target, mod_base, mod_pcsc);

    steps.check.dependOn(&b.addTest(.{ .root_module = mod_pcsc }).step);

    steps.ci.dependOn(steps.fmt);
    steps.ci.dependOn(steps.tests);
}

fn addDepsUpdate(b: *std.Build, steps: *const Steps) void {
    const macos_run = b.addSystemCommand(&.{"./update.sh"});
    macos_run.setCwd(b.path("_build/macos/xcode_frameworks"));

    steps.macos_deps.dependOn(&macos_run.step);
}

fn addDocs(
    b: *std.Build,
    steps: *const Steps,
    mod_pcsc: *std.Build.Module,
) void {
    const lib = b.addLibrary(.{
        .name = "pcsc",
        .root_module = mod_pcsc,
    });

    const docs_install = base.addDocs(b, lib, .{
        .html_logo = "PCSC",
        .install_dir = .prefix,
        .install_subdir = "docs",
        .repo_url = "https://github.com/kofi-q/pcsc-z",
    });

    steps.docs.dependOn(&docs_install.step);
}

fn addE2e(
    b: *std.Build,
    steps: *const Steps,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    mod_base: *std.Build.Module,
    mod_pcsc: *std.Build.Module,
) void {
    const exe = b.addExecutable(.{
        .name = "e2e",
        .root_module = b.createModule(.{
            .imports = &.{
                .{ .name = "base", .module = mod_base },
                .{ .name = "pcsc", .module = mod_pcsc },
            },
            .optimize = mode,
            .root_source_file = b.path("e2e/main.zig"),
            .target = target,
        }),
    });

    steps.e2e.dependOn(&b.addRunArtifact(exe).step);
}

fn addExamples(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    mod_base: *std.Build.Module,
    mod_pcsc: *std.Build.Module,
) void {
    inline for (examples.names) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .imports = &.{
                    .{ .name = "base", .module = mod_base },
                    .{ .name = "pcsc", .module = mod_pcsc },
                },
                .optimize = mode,
                .root_source_file = b.path(b.pathJoin(&.{
                    examples.dir, name, "main.zig",
                })),
                .target = target,
            }),
        });

        b.step("examples:" ++ name, "Run " ++ name ++ " example")
            .dependOn(&b.addRunArtifact(exe).step);
    }
}

fn addFmt(b: *std.Build, steps: *const Steps) void {
    const zig_fmt = b.addFmt(.{
        .check = isCi(),
        .paths = &.{
            "build.zig",
            "e2e",
            "examples",
            "src",
        },
    });

    steps.fmt.dependOn(&zig_fmt.step);
}

fn addTests(
    b: *std.Build,
    steps: *const Steps,
    mod_pcsc: *std.Build.Module,
) void {
    const run = b.addRunArtifact(b.addTest(.{ .root_module = mod_pcsc }));
    steps.tests.dependOn(&run.step);
}

fn linkPcsc(b: *std.Build, module: *std.Build.Module) void {
    const target = module.resolved_target.?.result;
    switch (target.os.tag) {
        .linux => {
            module.addLibraryPath(b.path(b.pathJoin(&.{
                "_build/linux/lib",
                b.fmt("{t}-{t}", .{ target.cpu.arch, target.abi }),
            })));

            module.linkSystemLibrary("pcsclite", .{});
        },

        .macos => {
            module.addSystemFrameworkPath(
                b.path("_build/macos/xcode_frameworks/Frameworks"),
            );

            module.linkFramework("PCSC", .{});
        },

        .windows => module.linkSystemLibrary("winscard", .{}),

        else => @panic(b.fmt("[pcsc-z] Unsupported target: {s}\n", .{
            target.zigTriple(b.allocator) catch @panic("OOM"),
        })),
    }
}

fn isCi() bool {
    return std.process.hasNonEmptyEnvVarConstant("CI");
}

fn modBase(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    return b.dependency("base", .{
        .optimize = mode,
        .target = target,
    }).module("base");
}

const examples = struct {
    const dir = "examples";

    const names = [_][]const u8{
        "transmit",
    };
};

const Steps = struct {
    check: *std.Build.Step,
    ci: *std.Build.Step,
    docs: *std.Build.Step,
    e2e: *std.Build.Step,
    fmt: *std.Build.Step,
    macos_deps: *std.Build.Step,
    tests: *std.Build.Step,
};
