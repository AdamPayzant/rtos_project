const std = @import("std");

const atomic = std.atomic;

const riscv = @import("target_specific/riscv/tools.zig");
const irq = @import("target_specific/riscv/interrupts.zig");

const LockState = enum(u32) {
    UNLOCKED = 0b00,
    LOCKED = 0b01,
};

pub const Spinlock = struct {
    const Self = @This();

    locked: atomic.Atomic(u32),
    holding_hart: ?usize,

    pub fn init() Spinlock {
        return Spinlock{
            .locked = atomic.Atomic(u32).init(0),
            .holding_hart = null,
        };
    }

    pub fn lock(self: *Self) void {
        // Make sure the hart isn't holding the lock
        if (self.holding_hart == riscv.get_hart_id()) {
            @panic("hart attempted to double lock");
        }

        irq.disable_interrupts();
        self.locked.store(@intFromEnum(LockState.LOCKED), atomic.Ordering.Unordered);
        self.holding_hart = riscv.get_hart_id();
    }

    pub fn trylock(self: *Self) bool {
        return self.locked == LockState.UNLOCKED;
    }

    pub fn unlock(self: *Self) void {
        if (self.holding_hart != riscv.get_hart_id()) {
            @panic("Non-owning thread attempted to free lock");
        }

        irq.enable_interrupts();
        self.locked.store(@intFromEnum(LockState.UNLOCKED), atomic.Ordering.Unordered);
        self.holding_hart = null;
    }
};
