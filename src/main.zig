const std = @import("std");

const uart = @import("uart.zig");

export fn kmain() noreturn {
    uart.print_str("Hello World\n");

    while (true) {
        var b = uart.read_byte();
        uart.write_byte(b);
    }
}
