const std = @import("std");

const StackTrace = std.builtin.StackTrace;

const platform_defs = @import("target_specific/riscv/virt/platform_defs.zig");
const uart = @import("uart.zig");
const sbi = @import("target_specific/riscv/sbi.zig");
const lock = @import("locks.zig");
const irq = @import("interrupts.zig");
const kmem = @import("kmem/kmem.zig");
const page = @import("kmem/page.zig");
const mem_bindings = @import("kmem/mem_bindings.zig");

const KAllocator = kmem.KAllocator;

var serial = uart.UART.init(platform_defs.UART_ADDR);

const logger = std.log.scoped(.kmain);

// Utility functions

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = error_return_trace;

    // We want to disable interrupts as we're trying to crash and
    // shouldn't be interrupted
    // irq.disable_interrupts();

    // uart.write_string(&serial, "ERROR: System Panic\n\n");
    // uart.write_string(&serial, "Panic message: \n");
    // uart.write_string(&serial, msg);
    // uart.write_string(&serial, "\n");
    logger.err("Error: System Panic\n\nPanic message: \n{s}\n", .{msg});

    sbi.shutdown();
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = logfn,
};

pub fn logfn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Ignore all non-error logging from sources other than
    // .my_project, .nice_library and the default
    const scope_prefix = "(" ++ switch (scope) {
        std.log.default_log_scope => @tagName(scope),
        else => @tagName(scope),
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    var writer = sbi.SBIWriter{};

    std.fmt.format(writer.writer(), prefix ++ format ++ "\n", args) catch return;
}

// Actual logic

export fn kmain() noreturn {
    logger.debug("Log test", .{});
    logger.debug("Log test2", .{});
    // TODO: Configure paging
    page.initialize_vmem_mapping();

    serial.set_FIFO();

    uart.write_string(&serial, "Hello World\n");

    var buffer: [128]u8 = undefined;

    // var kallocator = KAllocator.init(&serial);
    // const alloc = kallocator.allocator();
    // var dyn_buffer = alloc.alloc(u8, 12) catch @panic("Failed to allocate");
    // alloc.free(dyn_buffer);
    // page.page_init();
    // var buf = page.page_alloc(10) orelse @panic("Failed to allocate");
    // if (buf[0] != 0) {
    //     @panic("Data failed to be zeroed");
    // }
    // page.page_free(@ptrCast(buf));

    while (true) {
        const size = uart.read_string(&serial, &buffer);
        uart.write_string(&serial, "Received the following message:\n");
        uart.write_string(&serial, buffer[0..size]);
        if (std.mem.eql(u8, buffer[0 .. size - 1], "quit")) {
            break;
        }

        if (std.mem.eql(u8, buffer[0 .. size - 1], "ecall")) {
            uart.write_string(&serial, "Running ecall\n");
            asm volatile ("ecall");
        }
    }

    sbi.shutdown();
}
