pub fn get_hart_id() usize {
    return asm volatile ("mv %[result], tp"
        : [result] "=r" (-> usize),
    );
}
