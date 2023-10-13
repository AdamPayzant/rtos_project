const std = @import("std");

const Target = std.Target;
const LazyPath = std.build.LazyPath;
const ArrayList = std.ArrayList;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Collect flags
    const gdb = b.option(bool, "gdb", "Run qemu with debugging on port 1234") orelse false;

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    //const target = b.standardTargetOptions(.{});
    const target = std.zig.CrossTarget{
        .cpu_arch = Target.Cpu.Arch.riscv64,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
    };

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rtos_project",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.code_model = .medium;
    exe.single_threaded = true;

    exe.addAssemblyFile(LazyPath{ .path = "src/target_specific/riscv/virt/boot.S" });
    exe.addAssemblyFile(LazyPath{ .path = "src/target_specific/riscv/virt/interrupts.S" });

    exe.setLinkerScript(LazyPath{ .path = "src/target_specific/riscv/virt/linker.ld" });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    b.default_step.dependOn(&exe.step);

    var qemu_params = ArrayList([]const u8).init(b.allocator);
    qemu_params.appendSlice(&[_][]const u8{
        "qemu-system-riscv64",
        "-machine",
        "virt",
        "-nographic",
        "-bios",
        "default",
        "-smp",
        "4",
        "-m",
        "128M",
        "-kernel",
        "zig-out/bin/rtos_project",
    }) catch {};
    if (gdb) {
        qemu_params.appendSlice(&[_][]const u8{ "-S", "-s" }) catch {};
    }

    const qemu = b.addSystemCommand(qemu_params.items);
    qemu.step.dependOn(b.default_step);
    const run_step = b.step("run", "Run in qemu");
    run_step.dependOn(&qemu.step);
}
