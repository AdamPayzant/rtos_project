
.global irq_context_switch
.align 4
irq_context_switch:
  // Make room on the stack
  addi sp, sp, -256
  // Store all registers
  // TODO: Only conditionally save ra and sp, depending on the irq
  sd x1, 0(sp) // ra
  sd x2, 1 * 8(sp) // sp
  sd x3, 2 * 8(sp)
  sd x4, 3 * 8(sp)
  sd x5, 4 * 8(sp)
  sd x6, 5 * 8(sp)
  sd x7, 6 * 8(sp)
  sd x8, 7 * 8(sp)
  sd x9, 8 * 8(sp)
  sd x10, 9 * 8(sp)
  sd x11, 10 * 8(sp)
  sd x12, 11 * 8(sp)
  sd x13, 12 * 8(sp)
  sd x14, 13 * 8(sp)
  sd x15, 14 * 8(sp)
  sd x16, 15 * 8(sp)
  sd x17, 16 * 8(sp)
  sd x28, 27 * 8(sp)
  sd x29, 28 * 8(sp)
  sd x30, 29 * 8(sp)
  sd x31, 30 * 8(sp)


  call interrupt_dispatch
  
  // Restore registers 
  ld x1, 0(sp) // ra
  ld x2, 1 * 8(sp) // sp
  ld x3, 2 * 8(sp)
  ld x4, 3 * 8(sp)
  ld x5, 4 * 8(sp)
  ld x6, 5 * 8(sp)
  ld x7, 6 * 8(sp)
  ld x8, 7 * 8(sp)
  ld x9, 8 * 8(sp)
  ld x10, 9 * 8(sp)
  ld x11, 10 * 8(sp)
  ld x12, 11 * 8(sp)
  ld x13, 12 * 8(sp)
  ld x14, 13 * 8(sp)
  ld x15, 14 * 8(sp)
  ld x16, 15 * 8(sp)
  ld x17, 16 * 8(sp)
  ld x28, 27 * 8(sp)
  ld x29, 28 * 8(sp)
  ld x30, 29 * 8(sp)
  ld x31, 30 * 8(sp)

  sret

.global register_interrupt_control
register_interrupt_control:
  // Register interrupt context switch for S interrupts 
  csrw stvec, irq_context_switch
  ret
