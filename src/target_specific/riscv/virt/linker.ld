/* Specify architecture */
OUTPUT_ARCH(riscv)

/* Where to enter */
ENTRY(_start)

/* Base address from SBI */
BASE_ADDRESS = 0x80200000;


SECTIONS {
  . = BASE_ADDRESS;
  kernel_start = .;

  . = ALIGN(4K); /* alignment  for page size 4k */
  text_start = .;
  .text : {
     *(.text.entry)
     *(.text .text.*)
  }

  . = ALIGN(4K);
  rodata_start = .;
  .rodata : {
    *(.rodata .rodata.*)
  }

  . = ALIGN(4K);
  data_start = .;
  .data : {
    *(.data .data.*)
  }

  . = ALIGN(4K);
  bss_start = .;
  .bss : {
    *(.sbss .bss .bss.*)
  }

  . = ALIGN(4K);
  kernel_end = .;
}
