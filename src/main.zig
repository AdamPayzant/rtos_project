const std = @import("std");

const uart = @import("uart.zig");
const sbi = @import("target_specific/riscv/sbi.zig");

export fn kmain() noreturn {
    uart.print_str("Hello World\n");

    sbi.shutdown();
    while (true) {} // Just to shut up the zig compiler

    //while (true) {
    //    var b = uart.read_byte();
    //    uart.write_byte(b);
    //}
}
