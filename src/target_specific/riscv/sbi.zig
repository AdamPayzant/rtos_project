// SBI functions

const SBI_Call_Ret = struct {
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
    asm volatile ("ecall"
        : [arg0] "+{x10}" (arg0),
          [arg1] "+{x11}" (arg1),
        : [arg2] "{x10}" (arg2),
          [arg3] "{x11}" (arg3),
          [arg4] "{x12}" (arg4),
          [arg5] "{x13}" (arg5),
          [fid] "{x16}" (fid),
          [eid] "{x17}" (eid),
        : "memory"
    );

    return SBI_Call_Ret{
        .err = arg0,
        .value = arg1,
    };
}

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

pub fn reboot(reset_type: ResetType, reason: ResetReason) void {
    _ = sbi_call(EXT_SRST, EXT_SRST_RESET, @intFromEnum(reset_type), @intFromEnum(reason), 0, 0, 0, 0);
}

pub fn shutdown() noreturn {
    _ = sbi_call(EXT_SRST, EXT_SRST_RESET, @intFromEnum(ResetType.SHUTDOWN), 0, 0, 0, 0, 0);
    while (true) {} // Shut up the Zig compiler
}
