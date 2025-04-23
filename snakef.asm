;snake game

org 0x100

jmp start


start : mov ax, 5


terminate : mov ax, 4c00h
int 21h