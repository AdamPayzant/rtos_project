const std = @import("std");

const uart = @import("../uart.zig");
const page = @import("page.zig");

const Allocator = std.mem.Allocator;

// Setup/management

const AllocList = struct {
    flags_size: usize,
};

var INTIALIZED: bool = false;

var HEAD: *AllocList = null;

pub fn kernel_memory_init() void {
    INTIALIZED = true;
}

pub fn get_head() *usize {
    return 0;
}

// A nicer, zig compliant allocator
pub const KAllocator = struct {
    const Self = @This();

    logger: *uart.UART,

    pub fn init(logger: *uart.UART) KAllocator {
        if (!INTIALIZED) {
            @panic("Memory allocation not initialized");
        }
        return KAllocator{
            .logger = logger,
        };
    }

    pub fn allocator(self: *Self) Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
        } };
    }
};

fn alloc(ctx: *anyopaque, n: usize, log2_align: u8, ra: usize) ?[*]u8 {
    _ = ra;
    _ = log2_align;

    const self: *KAllocator = @ptrCast(@alignCast(ctx));
    uart.write_string(self.logger, "Attempting to allocate\n");

    return page.page_alloc(n);
}

fn resize(ctx: *anyopaque, buf_unaligned: []u8, log2_buf_align: u8, new_size: usize, return_address: usize) bool {
    _ = return_address;
    _ = new_size;
    _ = log2_buf_align;
    _ = buf_unaligned;

    const self: *KAllocator = @ptrCast(@alignCast(ctx));
    uart.write_string(self.logger, "Attempting to resize\n");

    return false;
}

fn free(ctx: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    _ = return_address;
    _ = log2_buf_align;

    const self: *KAllocator = @ptrCast(@alignCast(ctx));
    uart.write_string(self.logger, "Attempting to free\n");
    page.page_free(@ptrCast(slice));
}
