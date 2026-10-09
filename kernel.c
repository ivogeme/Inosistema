#include <stdint.h>

#define COM1 0x3F8

static inline void outb(uint16_t port, uint8_t value)
{
    __asm__ volatile (
        "outb %0, %1"
        :
        : "a"(value), "Nd"(port)
    );
}

static inline uint8_t inb(uint16_t port)
{
    uint8_t value;

    __asm__ volatile (
        "inb %1, %0"
        : "=a"(value)
        : "Nd"(port)
    );

    return value;
}

static void serial_init(void)
{
    outb(COM1 + 1, 0x00); /* Desativa interrupcoes */
    outb(COM1 + 3, 0x80); /* Ativa divisor */
    outb(COM1 + 0, 0x01); /* 115200 baud */
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03); /* 8 bits, sem paridade, 1 stop */
    outb(COM1 + 2, 0xC7); /* FIFO */
    outb(COM1 + 4, 0x0B); /* Controle do modem */
}

static void serial_putc(char c)
{
    while ((inb(COM1 + 5) & 0x20) == 0) {
    }

    outb(COM1, (uint8_t)c);
}

static char serial_getc(void)
{
    while ((inb(COM1 + 5) & 0x01) == 0) {
    }

    return (char)inb(COM1);
}

static void print(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            serial_putc('\r');
        }

        serial_putc(*s++);
    }
}

static char upper(char c)
{
    if (c >= 'a' && c <= 'z') {
        return (char)(c - 'a' + 'A');
    }

    return c;
}

static void help(void)
{
    print("\nComandos disponiveis:\n");
    print("H - Ajuda\n");
    print("R - Verificar o kernel\n");
    print("E texto - Imprimir texto\n");
}

static void execute_command(char *cmd)
{
    char command = upper(cmd[0]);

    switch (command) {
        case '\0':
            break;

        case 'H':
            help();
            break;

        case 'R':
            print("\nKernel inicializado.\n");
            break;

        case 'E':
            if (cmd[1] == ' ') {
                print("\n");
                print(&cmd[2]);
                print("\n");
            } else {
                print("\nUso: E texto\n");
            }
            break;

        default:
            print("\nComando desconhecido. Use H.\n");
            break;
    }
}

static void shell(void)
{
    char buffer[64];
    uint8_t length = 0;

    for (;;) {
        print("\nMini-Kernel > ");
        length = 0;

        for (;;) {
            char c = serial_getc();

            if (c == '\r' || c == '\n') {
                serial_putc('\r');
                serial_putc('\n');
                buffer[length] = '\0';
                break;
            }

            if (c == '\b' || c == 0x7F) {
                if (length > 0) {
                    length--;
                    print("\b \b");
                }
                continue;
            }

            if (c >= 32 && c <= 126 &&
                length < sizeof(buffer) - 1) {
                buffer[length++] = c;
                serial_putc(c);
            }
        }

        execute_command(buffer);
    }
}

void main(void)
{
    serial_init();

    print("\nMini-Kernel experimental\n");
    print("Nucleo iniciado em modo real x86.\n");
    print("Digite H para obter ajuda.\n");

    shell();
}