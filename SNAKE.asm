org 0x100
jmp start

; =============================================
; DATA SECTION
; =============================================    
    title_art:
        db '              /\^/\^\          ',0
        db '            _|__|  O|          ',0
        db '      \/  /~     \_/ \         ',0
        db '       \_|_________/   \       ',0
        db '         \_______      \       ',0
        db '                 \      \      ',0
        db '                  |     |      ',0
        db '                 /      /      ',0
        db '                /     /        ',0
        db '              /      /         ',0
        db '             /     /           ',0
        db '           /     /             ',0
        db '          /     /              ',0
        db '         (      (              ',0
        db '          \      ~-____-~      ',0
        db '            ~-_           _-~  ',0
        db '               ~--______-~     ',0

    title        db '  S N A K E   G A M E    ',0  
    prompt       db '[1] Hard  [2] Easy  [ESC] Exit ',0

    ; Game State Variables
    border_col    db 0x0C
    current_dir   db 0x4D
    snake_len     dw 3
    tail_pos      dw 0
    speed_level   dw 2
    last_key      db 0
    score         dw 0
    rng_seed      dw 0xACE1

    ; Snake Data Structures
    snake_body_pos times 100 dw 0
    snake_head    db 0x01
    snake_body    db 0x0A
    snake_color   db 0x0A

    ; Food Data
    food_pos      dw 0
    food_char     db 0x04
    food_color    db 0x85

    ; Game Over Elements
    game_over_lines:
        db 0xC9,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBB,0  
        db 0xBA,' GAME OVER ',0xBA,0                                           
        db 0xC8,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBC,0  
    box_attr          db 0x4E
    game_over_restart db 'Press R to Restart',0
    game_over_exit    db 'Press ESC for Start Menu',0

    ; Score Display
    score_str     db 'SCORE: '
    score_buffer  db '00000$'

    ; Sound Data
    start_sound_freqs dw 1000, 1500, 2000
    start_sound_dur   dw 3, 2, 1



; =============================================
; CODE SECTION
; =============================================
start:
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov es, ax
    call clrscn

    mov si, title_art
    mov cx, 16
    mov dh, 3
    mov bl, 0x0E

.draw_art:
    mov ax, 160
    mul dh
    add ax, 40
    mov di, ax

.draw_char:
    lodsb
    test al, al
    jz .next_line
    mov ah, bl
    stosw
    jmp .draw_char

.next_line:
    inc dh
    loop .draw_art

    mov si, title
    mov di, 20*160 + 60
    mov cx, 25
    mov ah, 0x0A
.draw_title:
    lodsb
    stosw
    loop .draw_title

    mov si, prompt
    mov di, 22*160 + 50
    mov cx, 30
    mov ah, 0x0C
.draw_prompt:
    lodsb
    stosw
    loop .draw_prompt

    call wait_enter_esc
    jmp init_game
	
init_game:
    ; Reset game state variables
    mov word [snake_len], 3
    mov byte [current_dir], 0x4D  ; Right direction
    mov word [score], 0
    
    ; Clear snake body positions
    mov cx, 100
    xor ax, ax
    mov di, snake_body_pos
    rep stosw

    ; Reinitialize game screen
    call clrscn
    call DrawFrame
    call ClearInterior
    
    ; Reset snake starting position
    mov di, 12*160 + 40*2
    mov [snake_body_pos], di
    sub di, 2
    mov [snake_body_pos + 2], di
    sub di, 2
    mov [snake_body_pos + 4], di
    
    ; Generate new food and start game
    call GenerateFood
    jmp GameLoop

GameLoop:
    ; Main game loop that handles input, updates the game state, and redraws
    mov byte [last_key], 0
    call HandleInput
    call UpdateSnake
	call DrawFood
    call DrawSnake
	call DrawScore
    call Delay
    jmp GameLoop
	
	
	
	
; ----------------------------
; CORE GAME LOGIC
; ----------------------------
; Update snake position and check collisions
UpdateSnake:
    mov bx, [snake_len]
    dec bx
    shl bx, 1
    mov ax, [snake_body_pos + bx]
    mov [tail_pos], ax
    
    mov cx, [snake_len]
    dec cx
    mov si, cx
    shl si, 1
.move_loop:
    mov ax, [snake_body_pos + si - 2]
    mov [snake_body_pos + si], ax
    sub si, 2
    loop .move_loop
    
    mov di, [snake_body_pos]
    cmp byte [current_dir], 0x4B
    je .left_dir
    cmp byte [current_dir], 0x4D
    je .right_dir
    cmp byte [current_dir], 0x48
    je .up_dir
    cmp byte [current_dir], 0x50
    je .down_dir

.left_dir:
    sub di, 2
    jmp .check_collision
.right_dir:
    add di, 2
    jmp .check_collision
.up_dir:
    sub di, 160
    jmp .check_collision
.down_dir:
    add di, 160

.check_collision:
    cmp di, 160
    jl .game_over
    cmp di, 3840
    jge .game_over
    mov ax, di
    mov bx, 160
    xor dx, dx
    div bx
    cmp dx, 2
    jle .game_over
    cmp dx, 158
    jge .game_over

    mov cx, [snake_len]
    dec cx
    jz .update_head
    mov si, 2
.body_check:
    mov ax, [snake_body_pos + si]
    cmp di, ax
    je .game_over
    add si, 2
    loop .body_check

.update_head:
    mov [snake_body_pos], di
    cmp di, [food_pos]
    jne .no_food
    
    add word [score], 1
    inc word [snake_len]
    push ax
    push cx
    mov al, 0xB6
    out 0x43, al
    mov ax, 0x0A40
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    mov cx, 0x2000
.delay_loop:
    nop
    loop .delay_loop
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    pop cx
    pop ax

    call GenerateFood
    jmp .skip_tail_erase
    
.no_food:
    mov di, [tail_pos]
    mov word [es:di], 0x0720
    
.skip_tail_erase:
    ret

.game_over:
    call GameOverScreen

; Process keyboard input for direction changes
HandleInput:
    mov ah, 0x01
    int 0x16
    jz .no_input

.get_key:
    mov ah, 0x00
    int 0x16
    cmp ah, [last_key]
    je .no_input
    mov [last_key], ah
    cmp ah, 0x4B
    je .try_left
    cmp ah, 0x4D
    je .try_right
    cmp ah, 0x48
    je .try_up
    cmp ah, 0x50
    je .try_down
    ret

.try_left:
    cmp byte [current_dir], 0x4D
    jne .update_dir
    ret
.try_right:
    cmp byte [current_dir], 0x4B
    jne .update_dir
    ret
.try_up:
    cmp byte [current_dir], 0x50
    jne .update_dir
    ret
.try_down:
    cmp byte [current_dir], 0x48
    jne .update_dir
    ret

.update_dir:
    mov [current_dir], ah
    ret

.no_input:
    ret



; ----------------------------
; GRAPHICS ROUTINES
; ----------------------------
; Draw game border elements
DrawFrame:
    call clrscn
    call DrawTop
    call DrawSides
    call DrawBottom
    call DrawCorners
    ret

; Draw top border
DrawTop:
    xor di, di
    mov cx, 80
.DT:
    mov byte [es:di], 0xCD
    mov al, [border_col]
    mov byte [es:di+1], al
    add di, 2
    loop .DT
    ret
	
; Draw side borders
DrawSides:
    mov cx, 23
    mov di, 160
.VS:
    mov byte [es:di], 0xBA
    mov al, [border_col]
    mov byte [es:di+1], al
    mov si, di
    add si, 158
    mov byte [es:si], 0xBA
    mov al, [border_col]
    mov byte [es:si+1], al
    add di, 160
    loop .VS
    ret

; Draw bottom border
DrawBottom:
    mov di, 3840
    mov cx, 80
.DB:
    mov byte [es:di], 0xCD
    mov al, [border_col]
    mov byte [es:di+1], al
    add di, 2
    loop .DB
    ret
	
; Draw corner characters
DrawCorners:
    mov di, 0
    mov byte [es:di], 0xC9
    mov al, [border_col]
    mov byte [es:di+1], al
    mov di, 158
    mov byte [es:di], 0xBB
    mov al, [border_col]
    mov byte [es:di+1], al
    mov di, 3840
    mov byte [es:di], 0xC8
    mov al, [border_col]
    mov byte [es:di+1], al
    mov di, 3998
    mov byte [es:di], 0xBC
    mov al, [border_col]
    mov byte [es:di+1], al
    ret

; Clear playing field
ClearInterior:
    mov di, 160+2
    mov ax, 0x0720
    mov cx, 23
.R1:
    mov dx, 78
.C1:
    mov [es:di], ax
    add di, 2
    dec dx
    jnz .C1
    add di, 4
    dec cx
    jnz .R1
    ret

; Render snake body and head
DrawSnake:
    mov di, [tail_pos]
    mov ax, 0x0720
    mov [es:di], ax
    mov di, [snake_body_pos]
    mov al, [snake_head]
    mov ah, [snake_color]
    mov [es:di], ax
    mov cx, [snake_len]
    dec cx
    mov si, 2
.draw_body:
    mov di, [snake_body_pos + si]
    mov al, [snake_body]
    mov ah, [snake_color]
    mov [es:di], ax
    add si, 2
    loop .draw_body
    ret
	

; Draw food character
DrawFood:
    mov di, [food_pos]
    mov al, [food_char]
    mov ah, [food_color]
    mov [es:di], ax
    ret

; Display current score
DrawScore:
    pusha
    mov di, 0*160 + 2*2
    mov si, score_str
    mov cx, 6
    mov ah, 0x0E
.draw_label:
    lodsb
    mov [es:di], al
    mov byte [es:di+1], 0x0E
    add di, 2
    loop .draw_label

    mov ax, [score]
    mov bx, 10
    lea si, [score_buffer + 4]
.fill_buffer:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    cmp si, score_buffer
    jae .fill_buffer
    
    mov si, score_buffer
    mov cx, 5
.draw_numbers:
    lodsb
    mov [es:di], al
    mov byte [es:di+1], 0x0E
    add di, 2
    loop .draw_numbers
    
    popa
    ret
	
; ----------------------------
; FOOD MANAGEMENT
; ----------------------------
; Generate new food position
GenerateFood:
    pusha
.generate_new:
    call GetRandom
    and ax, 0x7F
    cmp ax, 78
    ja .generate_new
    cmp ax, 2
    jb .generate_new
    mov bx, ax

    call GetRandom
    and ax, 0x1F
    cmp ax, 23
    ja .generate_new
    cmp ax, 1
    jb .generate_new

    mov cx, 160
    mul cx
    shl bx, 1
    add ax, bx
    mov di, ax

    mov cx, [snake_len]
    mov si, 0
.check_loop:
    cmp di, [snake_body_pos + si]
    je .generate_new
    add si, 2
    loop .check_loop

    mov [food_pos], di
    popa
    ret
; Simple PRNG implementation
GetRandom:
    mov ax, [rng_seed]
    mov dx, 0x4D35
    mul dx
    add ax, 0x8A3D
    mov [rng_seed], ax
    ret

; ----------------------------
; GAME OVER HANDLING
; ----------------------------
; Display game over screen
GameOverScreen:
    mov di, 12*160 + 34*2
    mov si, game_over_lines
    mov bl, [box_attr]
    mov cx, 3

.draw_lines:
    push cx
.draw_chars:
    lodsb
    test al, al
    jz .next_line
    mov [es:di], al
    mov [es:di+1], bl
    add di, 2
    jmp .draw_chars

.next_line:
    add di, 160 - (13*2)
    pop cx
    loop .draw_lines
    
    push ax
    push cx
    push dx
    mov al, 0xB6
    out 0x43, al
    mov ax, 0xA040
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    mov cx, 0x2000
.delay1: loop .delay1
    mov ax, 0xD120
    out 0x42, al
    mov al, ah
    out 0x42, al
    mov cx, 0x3000
.delay2: loop .delay2
    mov ax, 0xE948
    out 0x42, al
    mov al, ah
    out 0x42, al
    mov cx, 0x4000
.delay3: loop .delay3
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    pop dx
    pop cx
    pop ax

    mov di, 16*160 + 32*2
    mov si, game_over_restart
    mov bl, 0x4E
    call DrawGameOverText

    mov di, 17*160 + 30*2
    mov si, game_over_exit
    call DrawGameOverText

.input_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 'r'
    je .restart
    cmp al, 'R'
    je .restart
    cmp ah, 0x01
    je .exit
    jmp .input_loop

.restart:
    jmp init_game

.exit:
    jmp start
; Draw text with specified color
DrawGameOverText:
    pusha
.draw_loop:
    lodsb
    test al, al
    jz .done
    mov ah, bl
    mov [es:di], ax
    add di, 2
    jmp .draw_loop
.done:
    popa
    ret
; ----------------------------
; INPUT HANDLING
; ----------------------------
; Handle menu input
wait_enter_esc:
    mov ah, 0
    int 0x16
    cmp al, '1'
    je .set_hard
    cmp al, '2'
    je .set_easy
    cmp al, 0x1B
    je .exited
    jmp wait_enter_esc

.set_hard:
    mov word [speed_level], 1
    jmp .play_start_sound

.set_easy:
    mov word [speed_level], 2

.play_start_sound:
    pusha
    mov cx, 3
    mov si, start_sound_freqs
    mov di, start_sound_dur
    
.play_sequence:
    mov bx, [si]
    mov dx, [di]
    mov al, 0xB6
    out 0x43, al
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    call .sound_delay
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    add si, 2
    add di, 2
    loop .play_sequence
    
    popa
    ret

.sound_delay:
    push cx
    mov cx, dx
.delay_loop:
    push cx
    mov cx, 0x5000
.inner_loop:
    loop .inner_loop
    pop cx
    loop .delay_loop
    pop cx
    ret

.exited:
    mov ax, 0x4C00
    int 0x21

; ----------------------------
; UTILITIES
; ----------------------------
; Clear screen
clrscn:
    push ax
    push cx
    push di
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    rep stosw
    pop di
    pop cx
    pop ax
    ret

; BIOS text output
print_str:
    push ax
.loop_ps:
    lodsb
    test al, al
    jz .done_ps
    mov ah, 0x0E
    mov bh, 0
    mov bl, 7
    int 0x10
    jmp .loop_ps
.done_ps:
    pop ax
    ret

; Control game speed
Delay:
    push cx
    push dx
    mov dx, [speed_level]
    shl dx, 1
.outer_delay:
    mov cx, 0x7FFF
.inner_delay:
    dec cx
    jnz .inner_delay
    dec dx
    jnz .outer_delay
    pop dx
    pop cx
    ret