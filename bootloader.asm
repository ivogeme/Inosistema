; Bootloader - prototipo em modo real x86
; Esta versao requer processador 386 ou superior.

[bits 16]
[org 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7C00
    sti

    mov [boot_drive], dl

    ; Carrega 15 setores a partir do setor 2.
    ; Destino fisico: 0000:1000
    mov ah, 0x02
    mov al, 15
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x1000
    int 0x13
    jc disk_error

    jmp 0x0000:0x1000

disk_error:
    mov si, msg_error

.print:
    lodsb
    test al, al
    jz .halt

    mov ah, 0x0E
    int 0x10
    jmp .print

.halt:
    cli
    hlt
    jmp .halt

boot_drive: db 0
msg_error: db "Erro ao carregar o kernel!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55