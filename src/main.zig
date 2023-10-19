const std = @import("std");

const StackTrace = std.builtin.StackTrace;

const platform_defs = @import("target_specific/riscv/virt/platform_defs.zig");
const uart = @import("uart.zig");
const sbi = @import("target_specific/riscv/sbi.zig");
const lock = @import("locks.zig");

var serial = uart.UART.init(platform_defs.UART_ADDR);

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = error_return_trace;

    uart.write_string(&serial, "ERROR: System Panic\n\n");
    uart.write_string(&serial, "Panic message: \n");
    uart.write_string(&serial, msg);
    uart.write_string(&serial, "\n");

    sbi.shutdown();
}

export fn kmain() noreturn {
    uart.write_string(&serial, "Hello World\n");

    var sp_lock = lock.Spinlock.init();
    sp_lock.lock();
    uart.write_string(&serial, "Lock Acquired\n");
    sp_lock.unlock();
    uart.write_string(&serial, "Lock Released\n");

    sbi.shutdown();
}
