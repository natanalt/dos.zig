.global _hello_start;
_hello_start:
    movb $0x2, %ah
    movb $'H', %dl
    int $0x21
    movb $'e', %dl
    int $0x21
    movb $'n', %dl
    int $0x21
    movb $'l', %dl
    int $0x21
    movb $'o', %dl
    int $0x21
    movb $13, %dl
    int $0x21
    movb $10, %dl
    int $0x21
    lret
.global _hello_end;
_hello_end:
