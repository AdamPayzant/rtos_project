const std = @import("std");

const Target = std.Target;
const LazyPath = std.Build.LazyPath;
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
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = Target.Cpu.Arch.riscv64,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
    } });
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rtos_project",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .medium,
        .single_threaded = true,
    });

    exe.addAssemblyFile(LazyPath{ .src_path = .{ .owner = b, .sub_path = "src/target_specific/riscv/virt/boot.S" } });
    // exe.addAssemblyFile(LazyPath{ .src_path = .{ .owner = b, .sub_path = "src/target_specific/riscv/interrupts.S" } });
    exe.addAssemblyFile(LazyPath{ .src_path = .{ .owner = b, .sub_path = "src/kmem/mem_bindings.S" } });

    exe.setLinkerScript(LazyPath{ .src_path = .{ .owner = b, .sub_path = "src/target_specific/riscv/virt/linker.ld" } });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    b.default_step.dependOn(&exe.step);

    var qemu_params = ArrayList([]const u8).init(b.allocator);
    // Trying to mimic the milkv duo
    qemu_params.appendSlice(&[_][]const u8{
        "qemu-system-riscv64",
        "-machine",
        "virt",
        "-nographic",
        "-bios",
        "default",
        "-smp",
        "2",
        "-m",
        "64M",
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

    // TODO: Figure out how to use Zig's test infrastucture
    // // Creates a step for unit testing. This only builds the test executable
    // // but does not run it.
    // const unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = b.standardTargetOptions(.{}),
    //     .optimize = optimize,
    // });

    // const run_unit_tests = b.addRunArtifact(unit_tests);

    // // Similar to creating the run step earlier, this exposes a `test` step to
    // // the `zig build --help` menu, providing a way for the user to request
    // // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_unit_tests.step);
}
