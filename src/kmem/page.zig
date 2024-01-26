const std = @import("std");

const uart = @import("../uart.zig");

extern const HEAP_START: usize;
extern const HEAP_SIZE: usize;

const PAGE_SIZE: usize = 4096;

// ! Without allocations_start there's some alignment issue
// ! initialized. I should probably investigate this
var initialized: bool = false;
var allocations_start: usize = 0;

const PageState = enum(u2) {
    Empty = 0,
    Taken = 1,
    SpanEnd = 2,
};

const PageData = struct {
    page_offset: usize,
};

pub fn page_init() void {
    if (initialized) return;

    const page_count: usize = HEAP_SIZE / PAGE_SIZE;

    var page_data: [*]PageState = @ptrFromInt(HEAP_START);

    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        page_data[i] = PageState.Empty;
    }

    var pages_occupied = std.math.divCeil(usize, page_count * @sizeOf(PageState), PAGE_SIZE) catch @panic("Could not calculate Page count");

    initialized = true;
    allocations_start = HEAP_START + (PAGE_SIZE * pages_occupied);
}

/// page_alloc
///
/// A page grained allocation for the system
///
/// size being the number of bits to allocate aligned on page boundaries
pub fn page_alloc(size: usize) ?[*]u8 {
    if (size == 0) return null;

    const page_count = HEAP_SIZE / PAGE_SIZE;
    const pages_required = std.math.divCeil(usize, size, PAGE_SIZE) catch @panic("Division Error\n");
    var page_data: [*]PageState = @ptrFromInt(HEAP_START);

    var i: usize = 0;
    var span_start: ?usize = null;
    var span_count: usize = 0;

    while (i < page_count) : (i += 1) {
        if (page_data[i] == PageState.Empty) {
            if (span_start) |_| {} else {
                span_start = i;
            }
            span_count += 1;
            if (span_count == pages_required) break;
        } else {
            if (span_start) |_| {
                span_start = null;
            }
        }
    }

    // No spans could be found
    if (span_count != pages_required) {
        return null;
    }

    if (span_start) |start| {
        // Claim the span
        i = start;
        while (i < start + size) : (i += 1) {
            page_data[i] = PageState.Taken;

            var data: *u4096 = @ptrFromInt(HEAP_START + (i * PAGE_SIZE));
            data.* = 0;
        }
        // Set the last one as the end of the span
        page_data[i] = PageState.SpanEnd;

        return @ptrFromInt(HEAP_START + (start * PAGE_SIZE));
    } else {
        @panic("Page allocation error, no start found");
    }
}

/// page_free
///
/// Free function for page_alloc
pub fn page_free(ptr: *u8) void {
    const page_count = HEAP_SIZE / PAGE_SIZE;

    var page_data: [*]PageState = @ptrFromInt(HEAP_START);
    var ptr_idx = (@intFromPtr(ptr) - HEAP_START) / PAGE_SIZE;

    while (ptr_idx < page_count) : (ptr_idx += 1) {
        if (page_data[ptr_idx] == PageState.SpanEnd) {
            page_data[ptr_idx] = PageState.Empty;
            break;
        }
        page_data[ptr_idx] = PageState.Empty;
    }
}

// Now that we have page allocations, lets get memory mapping working
// Note: Because our 2 main targets are QEMU virt and the Milk-V duo, we're using the Sv39 system
const TABLE_LEN: usize = 512;

pub const PageTable = struct { data: [TABLE_LEN]u64 };

pub const TableEntryBits = enum(u8) {
    None = 0,
    Valid = 1,
    Read = 1 << 1,
    Write = 1 << 2,
    Execute = 1 << 3,
    UserMode = 1 << 4,
    Global = 1 << 5,
    Accessed = 1 << 6,
    Dirty = 1 << 7,

    RWX = 0b111 << 1,
};

const PageError = error{
    InvalidRWXBits,
};

pub fn map(
    root: *PageTable,
    virt_addr: usize,
    phys_addr: usize,
    entry_bits: TableEntryBits,
    level: usize,
) !void {
    // Verify at least one permission bit is set
    if (entry_bits & TableEntryBits.RWX == 0) return PageError.InvalidRWXBits;

    // Extract the Virtual Page Number (vpn) and Physical Page Number (ppn)
    var vpn = [3]u9{
        (virt_addr >> 12) & std.math.maxInt(u9),
        (virt_addr >> 21) & std.math.maxInt(u9),
        (virt_addr >> 30) & std.math.maxInt(u9),
    };
    var ppn = [3]u26{
        (phys_addr >> 12) & std.math.maxInt(u9),
        (phys_addr >> 21) & std.math.maxInt(u9),
        (phys_addr >> 30) & std.math.maxInt(u26),
    };

    // Set the virtual pages
    var vp = &(root.*.data[vpn[2]]);
    var i: usize = 1;
    while (i >= level) : (i -= 1) {
        if (vp & TableEntryBits.Valid == 0) {
            var page = page_alloc(PAGE_SIZE);
            vp.* = (page >> 2) | TableEntryBits.Valid;
        }

        var entry: u64 = (vp & !(std.math.maxInt(u9))) << 2;
        vp = @ptrFromInt(entry + vpn[i]);
    }

    var physical_entry = (ppn[2] << 28) | (ppn[1] << 19) | (ppn[0] << 10) |
        @intFromEnum(entry_bits) |
        TableEntryBits.Valid;
    vp.* = physical_entry;
}

pub fn unmap(root: *PageTable) void {
    _ = root;
    var i: usize = 0;
    while (i < TABLE_LEN) : (i += 1) {}
}

fn virt_to_phys() void {}
