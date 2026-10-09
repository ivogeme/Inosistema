bootloader.asm

; bootloader.asm - Bootloader de 512 bytes em Modo Real x86
[bits 16]
[org 0x7C00]

start:
cli                     ; Desabilita interrupções durante o setup
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7C00          ; Pilha crescendo para baixo
sti

mov [boot_drive], dl    ; Salva o drive de boot vindo da BIOS  

; Carrega o Kernel do disco (Setor 2 em diante) para 0x0000:0x1000  
mov ah, 0x02            ; Função INT 13h, AH=02h (Ler setores)  
mov al, 15              ; Quantidade de setores (7.5KB)  
mov ch, 0               ; Cilindro 0  
mov cl, 2               ; Setor 2 (Setor 1 é o próprio bootloader)  
mov dh, 0               ; Cabeça 0  
mov dl, [boot_drive]    ; Drive de boot  
mov bx, 0x1000          ; Buffer ES:BX = 0x0000:0x1000  
int 0x13  
jc disk_error  

; Salta para o Kernel no endereço correto (físico 0x1000)  
jmp 0x0000:0x1000

disk_error:
mov si, msg_error
print_loop:
lodsb
or al, al
jz halt
mov ah, 0x0E
int 0x10
jmp print_loop

halt:
cli
hlt

boot_drive: db 0
msg_error:  db "Erro ao carregar Kernel do disco!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

entry.asm

; entry.asm - Ponto de entrada de 16-bit
[bits 16]
[extern main]
[global _start]

_start:
call main               ; Chama a função principal do C
cli
.loop:
hlt                     ; Trava a CPU se a main retornar
jmp .loop

kernel.c

#include <stdint.h>

#define UART_BASE 0x3F8
volatile uint8_t * const UART_DR  = (uint8_t *)UART_BASE;
volatile uint8_t * const UART_LSR = (uint8_t *)(UART_BASE + 5);

#define BUFFER_SIZE 64
#define MAX_ARQUIVOS 16
#define MAX_DRIVES 2

typedef struct {
char nome[8];
char ext[3];
uint16_t tamanho;
uint16_t setor_inicial;
} Arquivo;

typedef struct {
Arquivo dir[MAX_ARQUIVOS];
uint8_t num_arquivos;
} Drive;

Drive drives[MAX_DRIVES];
uint8_t drive_atual = 0;

// ---------- Driver de Disco Real (BIOS INT 13h) ----------
uint8_t bios_read_sector(uint8_t drive, uint8_t sector, uint16_t segment, uint16_t offset) {
uint8_t status;
asm volatile(
"int $0x13"
: "=a"(status)
: "a"(0x0201),            // AH=02h (ler), AL=01 (1 setor)
"c"((0 << 8) | sector), // CH=0, CL=setor
"d"((0 << 8) | drive),  // DH=0, DL=drive
"b"(offset),
"m"(*(struct { uint16_t seg; } *)&segment)
: "memory"
);
return status;
}

// ---------- UART Serial ----------
void uart_putc(char c) {
while (!(*UART_LSR & 0x20));
*UART_DR = c;
}

char uart_getc() {
while (!(*UART_LSR & 0x01));
return *UART_DR;
}

void uart_print(const char* s) {
while (*s) uart_putc(*s++);
}

// ---------- Shell e Sistema de Arquivos ----------
Arquivo* buscar_arquivo(const char* nome) {
Drive* d = &drives[drive_atual];
for (uint8_t i = 0; i < d->num_arquivos; i++) {
uint8_t match = 1;
for (int j = 0; j < 8; j++) {
if (nome[j] == 0 || nome[j] == ' ' || nome[j] == '\r' || nome[j] == '\n') break;
if (d->dir[i].nome[j] != nome[j]) { match = 0; break; }
}
if (match) return &d->dir[i];
}
return 0;
}

void listar_arquivos() {
Drive* d = &drives[drive_atual];
uart_print("\r\nArquivos:\r\n");
if (d->num_arquivos == 0) {
uart_print(" (nenhum arquivo)\r\n");
return;
}
for (uint8_t i = 0; i < d->num_arquivos; i++) {
uart_print(" - ");
for(int j = 0; j < 8; j++) {
if (d->dir[i].nome[j]) uart_putc(d->dir[i].nome[j]);
}
uart_print(".");
for(int j = 0; j < 3; j++) {
if (d->dir[i].ext[j]) uart_putc(d->dir[i].ext[j]);
}
uart_print("\r\n");
}
}

void criar_arquivo(char* nome) {
Drive* d = &drives[drive_atual];
if (d->num_arquivos >= MAX_ARQUIVOS) { uart_print("Erro: drive cheio\r\n"); return; }

int idx = d->num_arquivos;  
for (int i = 0; i < 8; i++) {  
    if (nome[i] != 0 && nome[i] != '\r' && nome[i] != '\n') d->dir[idx].nome[i] = nome[i];  
    else d->dir[idx].nome[i] = ' ';  
}  
for (int i = 0; i < 3; i++) d->dir[idx].ext[i] = ' ';  
d->dir[idx].tamanho = 512;  
d->dir[idx].setor_inicial = 20 + idx;  
d->num_arquivos++;  
uart_print("Arquivo criado!\r\n");

}

void deletar_arquivo(char* nome) {
Drive* d = &drives[drive_atual];
for (uint8_t i = 0; i < d->num_arquivos; i++) {
uint8_t match = 1;
for (int j = 0; j < 8; j++) {
if (nome[j] == 0 || nome[j] == ' ') break;
if (d->dir[i].nome[j] != nome[j]) { match = 0; break; }
}
if (match) {
for (uint8_t k = i; k < d->num_arquivos - 1; k++) d->dir[k] = d->dir[k+1];
d->num_arquivos--;
uart_print("Arquivo deletado!\r\n");
return;
}
}
uart_print("Arquivo nao encontrado\r\n");
}

void ler_arquivo(char* nome) {
Arquivo* a = buscar_arquivo(nome);
if (!a) { uart_print("Erro: nao encontrado\r\n"); return; }
uart_print("Conteudo lido do setor com sucesso!\r\n");
}

typedef void (program_ptr)();
void executar_programa(char nome) {
Arquivo* a = buscar_arquivo(nome);
if (!a) { uart_print("Arquivo nao encontrado\r\n"); return; }

uint8_t* endereco = (uint8_t*)0x3000;  
uart_print("Carregando programa do setor para 0x3000...\r\n");  
bios_read_sector(0x00, a->setor_inicial, 0x0000, 0x3000);  
  
program_ptr prog = (program_ptr)endereco;  
prog();

}

void trocar_drive(char letra) {
if (letra == 'A' || letra == 'a') drive_atual = 0;
else if (letra == 'B' || letra == 'b') drive_atual = 1;
else { uart_print("Drive invalido\r\n"); return; }
uart_print("Drive alterado\r\n");
}

void mostrar_ajuda() {
uart_print("\r\nComandos:\r\n R - teste\r\n L - listar\r\n C nome - criar\r\n D nome - deletar\r\n R+nome - ler\r\n X+nome - executar\r\n M letra - trocar drive\r\n H - ajuda\r\n");
}

void executar_comando(char* cmd) {
if (cmd[0] == 0) return;
switch(cmd[0]) {
case 'R':
if (cmd[1] == '+') ler_arquivo(&cmd[2]);
else uart_print("Sistema OK\r\n");
break;
case 'L': listar_arquivos(); break;
case 'C': criar_arquivo(&cmd[2]); break;
case 'D': deletar_arquivo(&cmd[2]); break;
case 'X': executar_programa(&cmd[2]); break;
case 'M': trocar_drive(cmd[2]); break;
case 'H': mostrar_ajuda(); break;
default: uart_print("Comando desconhecido\r\n"); break;
}
}

void shell() {
char buffer[BUFFER_SIZE];
uint8_t i = 0;
uart_print("\r\nMini-Kernel > ");
while(1) {
char c = uart_getc();
if (c == '\r' || c == '\n') {
buffer[i] = 0;
i = 0;
uart_print("\r\n");
executar_comando(buffer);
uart_print("Mini-Kernel > ");
} else if (c == 0x08 || c == 0x7F) { // Backspace
if (i > 0) {
i--;
uart_print("\b \b");
}
} else {
if (i < BUFFER_SIZE - 1) {
buffer[i++] = c;
uart_putc(c);
}
}
}
}

void main() {
drives[0].num_arquivos = 0;
drives[1].num_arquivos = 0;
shell();
while(1);
}

linker.ld

OUTPUT_FORMAT("binary")
ENTRY(_start)

SECTIONS
{
. = 0x1000;

.text : {  
    *(.text*)  
}  

.data : {  
    *(.data*)  
}  

.bss : {  
    *(.bss*)  
}

}

Makefile

CC = gcc
LD = ld
NASM = nasm

CFLAGS = -m16 -ffreestanding -fno-pie -fno-stack-protector -nostdlib -mpreferred-stack-boundary=2 -O2 -Wall
LDFLAGS = -m elf_i386 -T linker.ld --oformat binary

all: os-image.bin

bootloader.bin: bootloader.asm
$(NASM) -f bin bootloader.asm -o bootloader.bin

entry.o: entry.asm
$(NASM) -f elf32 entry.asm -o entry.o

kernel.o: kernel.c
$(CC) $(CFLAGS) -c kernel.c -o kernel.o

kernel.bin: entry.o kernel.o linker.ld
$(LD) $(LDFLAGS) entry.o kernel.o -o kernel.bin

os-image.bin: bootloader.bin kernel.bin
cat bootloader.bin kernel.bin > os-image.bin
dd if=/dev/zero bs=512 count=30 >> os-image.bin 2>/dev/null

run: os-image.bin
qemu-system-i386 -fda os-image.bin -nographic

clean:
rm -f *.o *.bin os-image.bin