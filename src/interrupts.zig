const SIE_REGISTER: usize = 0b1;

// Interrupt control functions

/// disable_interrupts
///
/// Disables interrupts on the given hart
pub fn disable_interrupts() void {
    asm volatile ("csrc sstatus, %[arg1]"
        :
        : [arg1] "r" (SIE_REGISTER),
    );
}

/// enable_interrupts
///
/// Enables interrupts on the given hart
pub fn enable_interrupts() void {
    asm volatile ("csrs sstatus, %[arg1]"
        :
        : [arg1] "r" (SIE_REGISTER),
    );
}

// Interrupt handlers

export fn supervisor_interrupt_dispatch(epc: usize, cause: usize, status: usize) void {
    _ = status;
    _ = cause;
    _ = epc;
    // Disable interrupts
    disable_interrupts();
}

fn unhandled() void {
    @panic("Unhandled interrupt detected");
}
