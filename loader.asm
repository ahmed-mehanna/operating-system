[BITS 16]
[ORG 0x7e00]

start:
    mov [DriveId], dl

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb NotSupported

    mov eax, 0x80000001
    cpuid
    test edx, (1 << 29)
    jz NotSupported
    test edx, (1 << 26)
    jz NotSupported

LoadKernel:
    mov si, ReadPacket
    mov word[si], 0x10
    mov word[si + 2], 100
    mov word[si + 4], 0
    mov word[si + 6], 0x1000
    mov dword[si + 8], 6
    mov dword[si + 0xc], 0
    mov dl, [DriveId]
    mov ah, 0x42
    int 0x13
    jc ReadError

GetMemInfoStart:
    mov eax, 0xe820
    mov edx, 0x534d4150
    xor ebx, ebx    ;; mov ebx, 0x00000000
    mov ecx, 20
    mov edi, 0x9000
    int 0x15
    jc NotSupported

GetMeMInfo:
    add edi, 20
    mov eax, 0xe820
    mov edx, 0x534d4150
    mov ecx, 20
    int 0x15
    jc GetMemDone
    test ebx, ebx
    jnz GetMeMInfo

GetMemDone:
TestA20:
    mov ax, 0xffff
    mov es, ax
    mov word[ds:0x7c00], 0xa200
    cmp word[es:0x7c10], 0xa200
    jne SetA20LineDone
    mov word[0x7c00], 0xb200
    cmp word[es:0x7c10], 0xb200
    je End
    
SetA20LineDone:
    xor ax,ax
    mov es,ax

SetVideoMode:
    mov ax, 3
    int 0x10

    cli
    lgdt [Gdt32Ptr]
    lidt [Idt32Ptr]

    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    jmp 8:PMEntry   ;;  Load CS with code segment
                    ;;  Code segment is 8d=8h bytes away from the beginning of GDT
                    ;;  To load CS we specify bytes:offset

ReadError:
NotSupported:
End:
    hlt
    jmp End

[BITS 32]
PMEntry:
    mov ax, 0x10    ;;  Data segment is 16d=10h bytes away from the beginning of GDT
                    ;;  To load the other segments we use move instruction
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7c00

    ;;  To print message
;     mov ecx, MessageLength
;     mov esi, Message
;     mov edi, 0xb8000
; Again:
;     mov ah, byte[esi]
;     mov byte[edi], ah
;     mov byte[edi + 1], 0xa
;     inc esi
;     add edi, 2
;     loop Again

    cld
    mov edi, 0x80000
    xor eax, eax
    mov ecx, 0x10000/4
    rep stosd

    mov dword[0x80000], 0x81007
    mov dword[0x81000], 10000111b



    lgdt [Gdt64Ptr]

    mov eax, cr4
    or eax, (1<<5)
    mov cr4, eax

    mov eax, 0x80000
    mov cr3, eax

    mov ecx, 0xc0000080
    rdmsr
    or eax, (1<<8)
    wrmsr

    mov eax, cr0
    or eax, (1<<31)
    mov cr0, eax

    jmp 8:LMEntry

PEnd:
    hlt
    jmp PEnd

[BITS 64]
LMEntry:
    mov rsp, 0x7c00

    cld
    mov rdi, 0x200000
    mov rsi, 0x10000
    mov rcx, 51200/8
    rep movsq

    jmp 0x200000
    

LEnd:
    hlt
    jmp LEnd

DriveId:    db  0
; Message:    db  "Hello from Protected Mode"
; MessageLength:  equ $-Message
ReadPacket: times 16 db 0

Gdt32:  dq  0
Code32: dw  0xffff
        dw  0
        db  0
        db  0x9a    ;;  p=1 dpl=00 s=1 [ex,dc,rw,ac]=1010
        db  0xcf    ;;  gr=1 sz=1 00 limit=1111
        db  0
Data32: dw  0xffff
        dw  0
        db  0
        db  0x92    ;;  p=1 dpl=00 s=1 [ex,dc,rw,ac]=0010
        db  0xcf
        db  0

Gdt32Length: equ $ - Gdt32
Gdt32Ptr:   dw  Gdt32Length - 1
            dd  Gdt32

Idt32Ptr:   dw  0
            dd  0


Gdt64:
    dq 0
    dq 0x0020980000000000

Gdt64Length: equ $ - Gdt64

Gdt64Ptr:   dw Gdt64Length - 1
            dd Gdt64
