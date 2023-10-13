const UART: *volatile u8 = @ptrFromInt(0x10000000);

pub fn write_byte(byte: u8) void {
    UART.* = byte;
    return;
}

pub fn read_byte() u8 {
    return UART.*;
}

pub fn print_str(str: []const u8) void {
    for (str) |char| {
        write_byte(char);
    }
    return;
}
