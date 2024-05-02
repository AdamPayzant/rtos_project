/*
Originally by:
Stephen Marz
6 October 2019
https://github.com/sgmarz/osblog

Modified by Adam Payzant
*/

/*
riscv is the name of the architecture that the linker understands
for any RISC-V target (64-bit or 32-bit).

We will further refine this by using -mabi=lp64 and -march=rv64gc
*/
OUTPUT_ARCH( "riscv" )

/*
We're setting our entry point to a symbol
called _start which is inside of boot.S. This
essentially stores the address of _start as the
"entry point", or where CPU instructions should start
executing.

In the rest of this script, we are going to place _start
right at the beginning of 0x8020_0000 because this is where
the virtual machine and many RISC-V boards will start executing.
*/
ENTRY( _start )

/*
The MEMORY section will explain that we have "ram" that contains
a section that is 'w' (writeable), 'x' (executable), and 'a' (allocatable).
We use '!' to invert 'r' (read-only) and 'i' (initialized). We don't want
our memory to be read-only, and we're stating that it is NOT initialized
at the beginning.

The Origin address has been changed to 0x80200000, as we are first booting
OpenSBI, which hands off to that address

Finally LENGTH = 256 tells the linker that we have 256 megabyte of RAM.
The linker will double check this to make sure everything can fit.

We can provide other pieces of memory, such as QSPI, or ROM, but we're
telling the linker script here that we have one pool of RAM.
*/
MEMORY
{
	ram  (wxa) : ORIGIN = 0x80200000, LENGTH = 256M
}

/*
We are now going to organize the memory based on which
section it is in. In assembly, we can change the section
with the ".section" directive. However, in C++ and Rust,
CPU instructions go into text, global constants go into
rodata, global initialized variables go into data, and
global uninitialized variables go into bss.
*/
SECTIONS
{
	. = ORIGIN(ram);
	kernel_start = .;

	. = ALIGN(4K);
	text_start = .;
	/*
	The first part of our RAM layout will be the text section.
	Since our CPU instructions are here, and our memory starts at
	0x8020_0000, we need our entry point to line up here.
	*/
	.text : {
		*(.text.entry)

		*(.text .text.*)
	}
	
	. = ALIGN(4K);
	.rodata : {
		*(.srodata .srodata.*)
		*(.rodata .rodata.*)
	} >ram AT>ram :text

	. = ALIGN(4K);
	.data : {
		*(.sdata .sdata.*)
		*(.data .data.*)
	}

	. = ALIGN(4K);
	.bss : {
		*(.bss .bss.*)
	}


	_memory_end = ORIGIN(ram) + LENGTH(ram);

	/* 
	Finally, our heap starts right after the kernel stack. This heap will be used mainly
	to dole out memory for user-space applications. However, in some circumstances, it will
	be used for kernel memory as well.

	We don't align here because we let the kernel determine how it wants to do this.
	*/
	PROVIDE(_heap_start = .);
	PROVIDE(_heap_size = _memory_end - _heap_start);
}
