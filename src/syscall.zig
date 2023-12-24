pub const Syscall = enum(usize) {
    UNKNOWN = 0,
};

pub fn syscall_dispatch(call: Syscall) void {
    switch (call) {
        else => {
            @panic("UNKNOWN SYSCALL");
        },
    }
}
