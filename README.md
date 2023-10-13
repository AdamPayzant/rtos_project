# Unamed RTOS Project

A RISC-V RTOS written in Zig. Mostly just a toy to learn more about riscv and rtos paradigms.

## Running

Run `zig build` to generate a binary under `zig-out/bin/rtos_project`.

To run in QEMU, run `zig build run` or `zig build run -Dgdb=true` to run with gdb enabled on port 1234.

