[bits 16]
[extern main]
[global _start]

_start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7C00

    sti

    o32 call main

.halt:
    cli
    hlt
    jmp .halt