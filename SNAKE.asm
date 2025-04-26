org 0x100

jmp start

; Data section with corrected ASCII art
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
prompt       db '[ENTER] Start  [ESC] Exit ',0


border_col   db 0x0C  ; Color code for the border (red in this case, using BIOS color codes) (Used in the 'draw_border' subroutine)
snake_head    db 0x01  ; Character code for the snake's head (Used in the 'draw_snake' subroutine)
snake_body    db 0x02  ; Character code for the snake's body (Used in the 'draw_snake' subroutine)
snake_color   db 0x0A  ; Color code for the snake (light green in this case) (Used in the 'draw_snake' subroutine)

current_dir   db 0x4D  ; Direction of the snake's movement (0x4D corresponds to 'Right') (Used in 'move_snake' subroutine)
snake_len     dw 3   ; Initial length of the snake (starting with a length of 10) (Used in the 'move_snake' and 'draw_snake' subroutines)
snake_body_pos times 100 dw 0  ; Array holding the positions of the snake's body parts (initialized with 0) (Used in the 'move_snake', 'draw_snake', 'collision_check' subroutines)
tail_pos      dw 0     ; Position of the snake's tail (Used in 'move_snake' and 'draw_snake' subroutines)
speed_level   dw 2   ; Speed level of the game (1 is the initial speed) (Used in the 'game_loop' subroutine for controlling game speed)
last_key      db 0     ; Stores the last key pressed by the user for direction control (Used in the 'handle_input' and 'game_loop' subroutines)

;game over box
game_over_lines:
    db 0xC9,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBB,0  
    db 0xBA,' GAME OVER ',0xBA,0                                           
    db 0xC8,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBC,0  
box_attr db 0x4E  ; Yellow on red

; Food generation data
food_pos      dw 0       ; Position of current food
food_char     db 0x04    ; Diamond character (♦)
food_color    db 0x85    ; Light red color
rng_seed   dw 0xACE1   ; Initial seed (can be anything non-zero)


;score counter
score         dw 0              ; Current score
score_str     db 'SCORE: '      ; Score label
score_buffer  db '00000$'       ; Buffer for score digits (5 digits max)

; Add this to your data section
start_sound_freqs dw 1000, 1500, 2000  ; Frequency sequence
start_sound_dur   dw 3, 2, 1           ; Duration sequence (in ticks)



;--------------------------- FOOD GENERATION ------------------------------
GenerateFood:
    pusha
.generate_new:
    ; Get random X position (columns 2-78)
    call GetRandom
    and ax, 0x7F         ; Mask to 0-127
    cmp ax, 78
    ja .generate_new
    cmp ax, 2
    jb .generate_new
    mov bx, ax           ; Store X in BX

    ; Get random Y position (rows 1-23)
    call GetRandom
    and ax, 0x1F         ; Mask to 0-31
    cmp ax, 23
    ja .generate_new
    cmp ax, 1
    jb .generate_new

    ; Calculate video memory offset: DI = (Y * 160) + (X * 2)
    mov cx, 160
    mul cx               ; AX = Y * 160
    shl bx, 1            ; BX = X * 2
    add ax, bx           ; AX = final position
    mov di, ax

    ; Check collision with snake body
    mov cx, [snake_len]
    mov si, 0
.check_loop:
    cmp di, [snake_body_pos + si]
    je .generate_new     ; Collision found, try again
    add si, 2
    loop .check_loop

    ; Valid position found - store it
    mov [food_pos], di
    popa
    ret

GetRandom:
    mov ax, [rng_seed]
    mov dx, 0x4D35     ; Multiplier (use 214013 for better results but needs 32-bit)
    mul dx
    add ax, 0x8A3D     ; Increment
    mov [rng_seed], ax
    ret

;--------------------------- DRAW FOOD ------------------------------------
DrawFood:
    mov di, [food_pos]
    mov al, [food_char]
    mov ah, [food_color]
    mov [es:di], ax
    ret

GameOverScreen:
    ; Center position: row 12, column 34 (80-13)/2=33.5 → 34
    mov di, 12*160 + 34*2  ; 12th row (12*160=0x960), 34th column (34*2=0x44)
    mov si, game_over_lines
    mov bl, [box_attr]
    mov cx, 3               ; 3 lines

.draw_lines:
    push cx
.draw_chars:
    lodsb                   ; Read character
    test al, al             ; Check for null terminator
    jz .next_line
    mov [es:di], al         ; Draw character
    mov [es:di+1], bl       ; Set attribute
    add di, 2               ; Next screen position
    jmp .draw_chars

.next_line:
    add di, 160 - (13*2)    ; Move to next line: 160 - 26 = 134 bytes
    pop cx
    loop .draw_lines
	
	
; Alternative multi-tone losing sound
push ax
push cx
push dx

; First tone
mov al, 0xB6
out 0x43, al
mov ax, 0xA040     ; 400Hz
out 0x42, al
mov al, ah
out 0x42, al
in al, 0x61
or al, 0x03
out 0x61, al
mov cx, 0x2000
.delay1: loop .delay1

; Second tone
mov ax, 0xD120     ; 300Hz
out 0x42, al
mov al, ah
out 0x42, al
mov cx, 0x3000
.delay2: loop .delay2

; Final tone
mov ax, 0xE948     ; 200Hz
out 0x42, al
mov al, ah
out 0x42, al
mov cx, 0x4000
.delay3: loop .delay3

; Disable speaker
in al, 0x61
and al, 0xFC
out 0x61, al

pop dx
pop cx
pop ax

    ; Wait for any key
    mov ah, 0
    int 0x16
    
    ; Exit to DOS
    mov ax, 0x4C00
    int 0x21
	
clrscn:
    ; Clears the screen by filling it with spaces
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

print_str:
    ; Prints a string on the screen using BIOS interrupt
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

wait_enter_esc:
    mov ah, 0
    int 0x16                ; Wait for key
    cmp al, 0x0D            ; Enter key
    je .play_start_sound
    cmp al, 0x1B            ; Esc key
    je .exited
    jmp wait_enter_esc

.play_start_sound:
    ; Play startup sound sequence
    pusha
    mov cx, 3               ; Number of tones
    mov si, start_sound_freqs
    mov di, start_sound_dur
    
.play_sequence:
    mov bx, [si]            ; Frequency
    mov dx, [di]            ; Duration
    
    ; Program PC speaker
    mov al, 0xB6
    out 0x43, al
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    
    ; Turn on speaker
    in al, 0x61
    or al, 0x03
    out 0x61, al
    
    ; Wait duration
    call .sound_delay
    
    ; Turn off speaker
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

DrawFrame:
    ; Draws the frame of the game (top, sides, bottom, corners)
    call clrscn
	call DrawTop
    call DrawSides
    call DrawBottom
    call DrawCorners
    ret

DrawTop:
    ; Draws the top border of the game screen
    xor di, di
    mov cx, 80
.DT:
    mov byte [es:di], 0xCD
    mov al, [border_col]
    mov byte [es:di+1], al
    add di, 2
    loop .DT
    ret

DrawSides:
    ; Draws the left and right side borders of the game screen
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

DrawBottom:
    ; Draws the bottom border of the game screen
    mov di, 3840
    mov cx, 80
.DB:
    mov byte [es:di], 0xCD
    mov al, [border_col]
    mov byte [es:di+1], al
    add di, 2
    loop .DB
    ret

DrawCorners:
    ; Draws the four corners of the game screen
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

ClearInterior:
    ; Clears the interior of the game screen (removes snake and other elements)
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

HandleInput:
    ; Handles user input (left, right, up, down, or no input)
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
    ; Updates the direction based on user input
    mov [current_dir], ah
    ret

.no_input:
    ret

;--------------------------- UPDATE SNAKE POSITION ------------------------
UpdateSnake:
    ; Save tail position for erasing
    mov bx, [snake_len]
    dec bx                  
    shl bx, 1               
    mov ax, [snake_body_pos + bx]
    mov [tail_pos], ax
    
    ; Move body segments
    mov cx, [snake_len]
    dec cx
    mov si, cx
    shl si, 1           
.move_loop:
    mov ax, [snake_body_pos + si - 2]
    mov [snake_body_pos + si], ax
    sub si, 2
    loop .move_loop
    
    ; Update head position based on direction
    mov di, [snake_body_pos]
    cmp byte [current_dir], 0x4B    ; Left
    je .left_dir
    cmp byte [current_dir], 0x4D    ; Right
    je .right_dir
    cmp byte [current_dir], 0x48    ; Up
    je .up_dir
    cmp byte [current_dir], 0x50    ; Down
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
    ; Wall collision check
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

    ; Body collision check (NEW CODE)
    mov cx, [snake_len]
    dec cx              ; Skip head (index 0)
    jz .update_head     ; No body to check if length 1
    mov si, 2           ; Start at first body segment (index 1)
.body_check:
    mov ax, [snake_body_pos + si]
    cmp di, ax          ; Compare head position with body segment
    je .game_over
    add si, 2           ; Next body segment
    loop .body_check

.update_head:
    ; Update head position
    mov [snake_body_pos], di
    
    ; Check if head hit food
    cmp di, [food_pos]
    jne .no_food
    
	; Food collision detected - increase score and length
    add word [score], 1  ; Increase score by 1 points
    inc word [snake_len]
	
 push ax
    push cx
    ; Program PC speaker
    mov al, 0xB6        ; Timer 2, Square wave
    out 0x43, al
    mov ax, 0x0A40      ; Frequency (1193180 Hz / 0x0A40 = ~800Hz)
    out 0x42, al        ; Send low byte
    mov al, ah
    out 0x42, al        ; Send high byte
    ; Enable speaker
    in al, 0x61
    or al, 0x03         ; Set bits 0 and 1
    out 0x61, al
    ; Keep sound on for short duration
    mov cx, 0x2000      ; Adjust this value for duration
.delay_loop:
    nop
    loop .delay_loop
    ; Disable speaker
    in al, 0x61
    and al, 0xFC        ; Clear bits 0 and 1
    out 0x61, al
    
    pop cx
    pop ax

    call GenerateFood
    jmp .skip_tail_erase
    
.no_food:
    ; Normal movement - erase tail
    mov di, [tail_pos]
    mov word [es:di], 0x0720  ; Space with white attribute
    
.skip_tail_erase:
    ret

.game_over:
	call GameOverScreen

;--------------------------- DRAW SCORE DISPLAY ---------------------------
DrawScore:
    pusha
    ; Set position (row 0, column 2)
    mov di, 0*160 + 2*2
    
    ; Draw "SCORE: " text
    mov si, score_str
    mov cx, 6            ; Length of "SCORE: "
    mov ah, 0x0E         ; Yellow on black
.draw_label:
    lodsb
    mov [es:di], al
    mov byte [es:di+1], 0x0E
    add di, 2
    loop .draw_label
    
    ; Convert score to ASCII
    mov ax, [score]
    mov bx, 10
    lea si, [score_buffer + 4] ; Start from end of buffer
    
.fill_buffer:
    xor dx, dx
    div bx              ; AX = quotient, DX = remainder
    add dl, '0'         ; Convert to ASCII
    mov [si], dl
    dec si
    cmp si, score_buffer
    jae .fill_buffer
    
    ; Draw score numbers
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

Delay:
    ; Introduces a delay in the game loop to control game speed
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

DrawSnake:
    ; Draws the snake on the screen (head and body)
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

start:
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov es, ax
    call clrscn

    ; Draw ASCII art
    mov si, title_art         ; Source data
    mov cx, 16                ; Number of lines
    mov dh, 3                 ; Starting row
    mov bl, 0x0E              ; Yellow color

.draw_art:
    ; Calculate screen position: DI = (dh * 160) + 20
    mov ax, 160
    mul dh
    add ax, 40               ; Center at column 20 (20*2 bytes)
    mov di, ax

    ; Draw one line
.draw_char:
    lodsb                     ; Load character
    test al, al               ; Check for null terminator
    jz .next_line
    mov ah, bl                ; Set color attribute
    stosw                     ; Write to video memory
    jmp .draw_char

.next_line:
    inc dh                   ; Move to next row
    loop .draw_art

    ; Draw title
    mov si, title
    mov di, 20*160 + 60      ; Row 20, column 30
    mov cx, 25               ; Title length
    mov ah, 0x0A             ; Green color
.draw_title:
    lodsb
    stosw
    loop .draw_title

    ; Draw prompt
    mov si, prompt
    mov di, 22*160 + 50      ; Row 22, column 25
    mov cx, 25               ; Prompt length
    mov ah, 0x0C             ; Red color
.draw_prompt:
    lodsb
    stosw
    loop .draw_prompt

    call wait_enter_esc
    jmp init_game
init_game:
    ; Initializes the game state and starts the main game loop
    call clrscn
    call DrawFrame
    call ClearInterior
    mov di, 12*160 + 40*2
    mov [snake_body_pos], di
    sub di, 2
    mov [snake_body_pos + 2], di
    sub di, 2
    mov [snake_body_pos + 4], di
    
	call GenerateFood
    jmp GameLoop