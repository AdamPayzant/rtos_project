.section .text.entry
.global _start

_start:
  # Move the top of stack to the stack pointer
  la sp, boot_stack_top
  # Start the kernel
  call kmain

# Set up boot stack
.section .bss.stack 
.global boot_stack 
boot_stack:
  # Make the boot stack 16K
  .space 4096 * 16
  .global boot_stack_top
boot_stack_top:
  # End of stack
