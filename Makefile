CC = gcc
LD = ld
NASM = nasm

CFLAGS = -m16 -march=i386 -ffreestanding -fno-pie -fno-pic \
         -fno-stack-protector -fno-builtin \
         -fno-asynchronous-unwind-tables -fno-unwind-tables \
         -nostdlib -O2 -Wall -Wextra

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
	test $$(wc -c < kernel.bin) -le 7680

os-image.bin: bootloader.bin kernel.bin
	test $$(wc -c < bootloader.bin) -eq 512
	cat bootloader.bin kernel.bin > os-image.bin
	truncate -s 1474560 os-image.bin

run: os-image.bin
	qemu-system-i386 -drive format=raw,file=os-image.bin,if=floppy \
		-boot a -display none -serial stdio -monitor none

clean:
	rm -f *.o *.bin os-image.bin

.PHONY: all run clean