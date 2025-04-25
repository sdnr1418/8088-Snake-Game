org 0x100
bits 16

jmp start

;-------------- DATA --------------
; Splash data & border color
title        db '   Snake Game BY sdnr   ', 0
prompt       db ' Press [Enter] to Start or [Esc] to Exit ', 0
border_col   db 0x0C      ; red-on-black

;-------------- CODE --------------
; clear screen (80×25)
clrscn:
    push ax
    push cx
    push di
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0720     ; space + attr=07h (white)
    mov cx, 2000       ; 80*25
    rep stosw
    pop di
    pop cx
    pop ax
    ret

; print ASCIIZ string at DS:SI
print_str:
    push ax
.loop_ps:
    lodsb
    test al, al
    jz .done_ps
    mov ah, 0x0E
    mov bh, 0
    mov bl, 7         ; white for text
    int 0x10
    jmp .loop_ps
.done_ps:
    pop ax
    ret

; wait for Enter/Esc
wait_enter_esc:
    mov ah, 0
    int 0x16
    cmp al, 0x0D      ; Enter
    je .entered
    cmp al, 0x1B      ; Esc
    je .exited
    jmp wait_enter_esc
.entered:
    ret
.exited:
    mov ax, 0x4C00
    int 0x21

; Draw complete border (red)
DrawFrame:
    call DrawTop
    call DrawSides
    call DrawBottom
    call DrawCorners
    ret

DrawTop:
    xor di, di
    mov cx, 80
.DT:
    mov byte [es:di], 0xCD      ; ═
    mov al, [border_col]
    mov byte [es:di+1], al
    add di, 2
    loop .DT
    ret

DrawSides:
    mov cx, 23
    mov di, 160        ; start of row1
.VS:
    ; left border
    mov byte [es:di], 0xBA      ; ║
    mov al, [border_col]
    mov byte [es:di+1], al
    ; right border
    mov si, di
    add si, 158                 ; 79*2
    mov byte [es:si], 0xBA
    mov al, [border_col]
    mov byte [es:si+1], al
    ; next row
    add di, 160
    loop .VS
    ret

DrawBottom:
    mov di, 3840      ; start of row24
    mov cx, 80
.DB:
    mov byte [es:di], 0xCD
    mov al, [border_col]
    mov byte [es:di+1], al
    add di, 2
    loop .DB
    ret

DrawCorners:
    ; TL at 0
    mov di, 0
    mov byte [es:di], 0xC9      ; ╔
    mov al, [border_col]
    mov byte [es:di+1], al

    ; TR at 158
    mov di, 158
    mov byte [es:di], 0xBB      ; ╗
    mov al, [border_col]
    mov byte [es:di+1], al

    ; BL at 3840
    mov di, 3840
    mov byte [es:di], 0xC8      ; ╚
    mov al, [border_col]
    mov byte [es:di+1], al

    ; BR at 3998
    mov di, 3998
    mov byte [es:di], 0xBC      ; ╝
    mov al, [border_col]
    mov byte [es:di+1], al
    ret

; clear interior rows1–23, cols1–78
ClearInterior:
    mov di, 160+2      ; row1,col1
    mov ax, 0x0720     ; space + white
    mov cx, 23
.R1:
    mov dx, 78
.C1:
    mov [es:di], ax
    add di, 2
    dec dx
    jnz .C1
    ; move to next row start (current di is at column79; add 4 to reach next row's column1)
    add di, 4
    dec cx
    jnz .R1
    ret

;-------------- MAIN --------------
start:
    ; DS = CS for data
    mov ax, cs
    mov ds, ax
    ; ES = B800h for video
    mov ax, 0xB800
    mov es, ax

    ; splash
    call clrscn
    ; print title
    mov ah,02h
    mov bh,0
    mov dh,10
    mov dl,20
    int 0x10
    mov si, title
    call print_str
    ; print prompt
    mov ah,02h
    mov bh,0
    mov dh,12
    mov dl,18
    int 0x10
    mov si, prompt
    call print_str
    ; wait
    call wait_enter_esc

    ; init game view
init_game:
    call clrscn
    call DrawFrame
    call ClearInterior
    ; hang
    jmp $


