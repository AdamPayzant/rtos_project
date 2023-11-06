const std = @import("std");

const StackTrace = std.builtin.StackTrace;

const platform_defs = @import("target_specific/riscv/virt/platform_defs.zig");
const uart = @import("uart.zig");
const sbi = @import("target_specific/riscv/sbi.zig");
const lock = @import("locks.zig");
const irq = @import("target_specific/riscv/interrupts.zig");

var serial = uart.UART.init(platform_defs.UART_ADDR);

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = error_return_trace;

    // We want to disable interrupts as we're trying to crash and
    // shouldn't be interrupted
    irq.disable_interrupts();

    uart.write_string(&serial, "ERROR: System Panic\n\n");
    uart.write_string(&serial, "Panic message: \n");
    uart.write_string(&serial, msg);
    uart.write_string(&serial, "\n");

    sbi.shutdown();
}

export fn kmain() noreturn {
    serial.set_FIFO();

    uart.write_string(&serial, "Hello World\n");

    var sp_lock = lock.Spinlock.init();
    sp_lock.lock();
    uart.write_string(&serial, "Lock Acquired\nblah\n");
    sp_lock.unlock();
    uart.write_string(&serial, "Lock Released\n");

    var buffer: [128]u8 = undefined;
    while (true) {
        var size = uart.read_string(&serial, &buffer);
        uart.write_string(&serial, "Received the following message:\n");
        uart.write_string(&serial, buffer[0..size]);
        if (std.mem.eql(u8, buffer[0 .. size - 1], "quit")) {
            break;
        }
    }

    sbi.shutdown();
}
