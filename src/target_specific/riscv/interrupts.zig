const SIE_REGISTER: usize = 0b1;

pub fn disable_interrupts() void {
    asm volatile ("csrc sstatus, %[arg1]"
        :
        : [arg1] "r" (SIE_REGISTER),
    );
}

pub fn enable_interrupts() void {
    asm volatile ("csrs sstatus, %[arg1]"
        :
        : [arg1] "r" (SIE_REGISTER),
    );
}
