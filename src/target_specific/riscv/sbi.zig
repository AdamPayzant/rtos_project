const std = @import("std");

// SBI functions

pub const SBI_Call_Ret = struct {
    err: usize,
    value: usize,
};

// SBI ecall base
fn sbi_call(
    eid: i32,
    fid: i32,
    arg0: usize,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
) SBI_Call_Ret {
    var err: usize = 0;
    var val: usize = 0;

    asm volatile ("ecall"
        : [err] "={x10}" (err),
          [val] "={x11}" (val),
        : [fid] "{x16}" (fid),
          [eid] "{x17}" (eid),
          [arg0] "{x10}" (arg0),
          [arg1] "{x11}" (arg1),
          [arg2] "{x12}" (arg2),
          [arg3] "{x13}" (arg3),
          [arg4] "{x14}" (arg4),
          [arg5] "{x15}" (arg5),
        : "memory"
    );

    return SBI_Call_Ret{
        .err = err,
        .value = val,
    };
}

// Debug functions
const SBI_EXT_0_1_CONSOLE_PUTCHAR: usize = 0x1;
fn put_char(c: u8) void {
    const res = sbi_call(SBI_EXT_0_1_CONSOLE_PUTCHAR, 0, c, 0, 0, 0, 0, 0);

    if (res.err != 0) {
        var code: i64 = @bitCast(res.err);
        code = std.math.absInt(code) catch @panic("SBI failed to put code AND we failed to absolute value it. Something's horribly wrong!");

        _ = sbi_call(SBI_EXT_0_1_CONSOLE_PUTCHAR, 0, @intCast(code), 0, 0, 0, 0, 0);
    }
}

pub const SBIWriter = struct {
    const Writer = std.io.Writer(*SBIWriter, error{}, write);

    pub fn write(self: *SBIWriter, data: []const u8) error{}!usize {
        _ = self;
        var count: usize = 0;
        for (data) |c| {
            put_char(c);
            count += 1;
        }
        return count;
    }

    pub fn writer(self: *SBIWriter) Writer {
        return .{ .context = self };
    }
};

// Power functions

// System reset extension
const EXT_SRST: i32 = 0x53525354;
const EXT_SRST_RESET: i32 = 0;

pub const ResetType = enum(usize) {
    SHUTDOWN = 0x00000000,
    COLD_REBOOT = 0x00000001,
    WARM_REBOOT = 0x00000002,
};

pub const ResetReason = enum(usize) {
    NO_REASON = 0x00000000,
    SYSTEM_FAILURE = 0x00000001,
};

pub fn reboot(reset_type: ResetType, reason: ResetReason) SBI_Call_Ret {
    return sbi_call(EXT_SRST, EXT_SRST_RESET, @intFromEnum(reset_type), @intFromEnum(reason), 0, 0, 0, 0);
}

pub fn shutdown() noreturn {
    _ = sbi_call(EXT_SRST, EXT_SRST_RESET, @intFromEnum(ResetType.SHUTDOWN), 0, 0, 0, 0, 0);
    while (true) {} // Shut up the Zig compiler
}
