const std = @import("std");

const uart = @import("../uart.zig");
const mem_bindings = @import("mem_bindings.zig");

const logger = std.log.scoped(.page);

pub const PAGE_SIZE: usize = 4096;

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

    logger.debug("Initializing paging", .{});

    const page_count: usize = mem_bindings.HEAP_SIZE / PAGE_SIZE;

    var page_data: [*]PageState = @ptrFromInt(mem_bindings.HEAP_START);

    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        page_data[i] = PageState.Empty;
    }

    const pages_occupied = std.math.divCeil(usize, page_count * @sizeOf(PageState), PAGE_SIZE) catch @panic("Could not calculate Page count");

    initialized = true;
    allocations_start = mem_bindings.HEAP_START + (PAGE_SIZE * pages_occupied);

    const addr: *volatile usize = @ptrFromInt(page_alloc(1) orelse @panic("Can't allocate"));
    addr.* = 1;
    logger.debug("Page init finished", .{});
}

/// page_alloc
///
/// A page grained allocation for the system
///
/// size being the number of bits to allocate aligned on page boundaries
pub fn page_alloc(size: usize) ?usize {
    if (size == 0) return null;

    const page_count = mem_bindings.HEAP_SIZE / PAGE_SIZE;
    const pages_required = std.math.divCeil(usize, size, PAGE_SIZE) catch @panic("Division Error\n");
    var page_data: [*]PageState = @ptrFromInt(mem_bindings.HEAP_START);

    logger.debug("Attempting to allocate {} pages", .{pages_required});

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
        logger.debug("Span found starting at {X}", .{start});
        // Claim the span
        i = start;
        while (i < start + size) : (i += 1) {
            page_data[i] = PageState.Taken;

            const data: *u4096 = @ptrFromInt(mem_bindings.HEAP_START + (i * PAGE_SIZE));
            data.* = 0;
        }
        // Set the last one as the end of the span
        page_data[i] = PageState.SpanEnd;

        return mem_bindings.HEAP_START + (start * PAGE_SIZE);
    } else {
        @panic("Page allocation error, no start found");
    }
}

/// page_free
///
/// Free function for page_alloc
pub fn page_free(ptr: usize) void {
    const page_count = mem_bindings.HEAP_SIZE / PAGE_SIZE;

    var page_data: [*]PageState = @ptrFromInt(mem_bindings.HEAP_START);
    var ptr_idx = (ptr - mem_bindings.HEAP_START) / PAGE_SIZE;

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
    const vpn = [3]u9{
        (virt_addr >> 12) & std.math.maxInt(u9),
        (virt_addr >> 21) & std.math.maxInt(u9),
        (virt_addr >> 30) & std.math.maxInt(u9),
    };
    const ppn = [3]u26{
        (phys_addr >> 12) & std.math.maxInt(u9),
        (phys_addr >> 21) & std.math.maxInt(u9),
        (phys_addr >> 30) & std.math.maxInt(u26),
    };

    // Set the virtual pages
    var vp = &(root.*.data[vpn[2]]);
    var i: usize = 1;
    while (i >= level) : (i -= 1) {
        if (vp & TableEntryBits.Valid == 0) {
            const page = page_alloc(PAGE_SIZE);
            vp.* = (page >> 2) | TableEntryBits.Valid;
        }

        const entry: u64 = (vp.* & (~std.math.maxInt(u9))) << 2;
        vp = @ptrFromInt(entry + vpn[i]);
    }

    const physical_entry = (ppn[2] << 28) | (ppn[1] << 19) | (ppn[0] << 10) |
        @intFromEnum(entry_bits) |
        TableEntryBits.Valid;
    vp.* = physical_entry;
}

pub fn unmap(root: *PageTable) void {
    var lvl2: usize = 0;
    while (lvl2 < TABLE_LEN) : (lvl2 += 1) {
        const entry = &(root.*.data[lvl2]);
        // Check if it's a valid branch
        if (entry & TableEntryBits.Valid != 0 and
            entry & TableEntryBits.RWX == 0)
        {
            const lvl1_addr = (entry.* & (~0x3ff)) << 2;
            const lvl1_table: *PageTable = @ptrFromInt(lvl1_addr);

            var lvl1: usize = 0;
            while (lvl1 < TABLE_LEN) : (lvl1 += 1) {
                const entry_lvl1 = lvl1_table.*.data[lvl1];

                if (entry_lvl1 & TableEntryBits.Valid != 0 and
                    entry_lvl1 & TableEntryBits.RWX == 0)
                {
                    const addr = (entry_lvl1 & (~0x3ff)) << 2;
                    page_free(@ptrFromInt(addr));
                }
            }
            page_free(@ptrFromInt(lvl1_addr));
        }
        // Root pages do not get freed here because they're generally mapped to processes
        // Must be freed manually
    }
}

fn virt_to_phys(root: *PageTable, virt_addr: usize) ?u64 {
    // Extract the Virtual Page Number (vpn) and Physical Page Number (ppn)
    const vpn = [3]u9{
        (virt_addr >> 12) & std.math.maxInt(u9),
        (virt_addr >> 21) & std.math.maxInt(u9),
        (virt_addr >> 30) & std.math.maxInt(u9),
    };
    var v = &(root.data[vpn[2]]);

    var i: usize = 2;
    while (i >= 0) : (i -= 1) {
        if (v & TableEntryBits.Valid == 0) {
            break;
        }
        // If it's a valid address, check if it's a leaf
        else if (v & TableEntryBits.RWX != 0) {
            const offset = (1 << (12 + i * 9)) - 1;
            const vaddr_pgoff = virt_addr & offset;
            return ((v.* << 2) & (~offset)) | vaddr_pgoff;
        }

        if (i == 0) {
            // Ideally we should never be getting here, but just to be safe
            break;
        }

        const entry: *u64 = (v.* & (~0x3ff)) << 2;
        v = @ptrFromInt(entry.* + vpn[i - 1]);
    }
    return null;
}

// Init logic

var table: ?*PageTable = null;

pub fn init_paging() void {
    page_init();

    table = @ptrFromInt(page_alloc(PAGE_SIZE) orelse @panic("Failed to allocate page table"));

    logger.debug("Setting vmem csr", .{});
    // Set csr satp
    asm volatile ("csrw satp, %[arg]"
        :
        : [arg] "r" ((@intFromPtr(table.?) >> 12) | (8 << 60)),
    );

    asm volatile ("sfence.vma");
    logger.debug("SV39 CSR set", .{});
}
