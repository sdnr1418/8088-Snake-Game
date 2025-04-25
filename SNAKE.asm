org 0x100

jmp start

; Data section
title        db '   Snake Game BY sdnr   ', 0    ; Title of the game, displayed at the start (Used in the 'start_screen' subroutine)
prompt       db ' Press [Enter] to Start or [Esc] to Exit ', 0  ; Prompt message for the user to start or exit the game (Used in the 'start_screen' subroutine)
border_col   db 0x0C  ; Color code for the border (red in this case, using BIOS color codes) (Used in the 'draw_border' subroutine)
snake_head    db 0x01  ; Character code for the snake's head (Used in the 'draw_snake' subroutine)
snake_body    db 0x02  ; Character code for the snake's body (Used in the 'draw_snake' subroutine)
snake_color   db 0x0A  ; Color code for the snake (light green in this case) (Used in the 'draw_snake' subroutine)

current_dir   db 0x4D  ; Direction of the snake's movement (0x4D corresponds to 'Right') (Used in 'move_snake' subroutine)
snake_len     dw 10    ; Initial length of the snake (starting with a length of 10) (Used in the 'move_snake' and 'draw_snake' subroutines)
snake_body_pos times 100 dw 0  ; Array holding the positions of the snake's body parts (initialized with 0) (Used in the 'move_snake', 'draw_snake', 'collision_check' subroutines)
tail_pos      dw 0     ; Position of the snake's tail (Used in 'move_snake' and 'draw_snake' subroutines)
speed_level   dw 1     ; Speed level of the game (1 is the initial speed) (Used in the 'game_loop' subroutine for controlling game speed)
last_key      db 0     ; Stores the last key pressed by the user for direction control (Used in the 'handle_input' and 'game_loop' subroutines)

game_over_lines:
    db 0xC9,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBB,0  
    db 0xBA,' GAME OVER ',0xBA,0                                           
    db 0xC8,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xBC,0  
box_attr db 0x4E  ; Yellow on red

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
    ; Waits for the user to press Enter or Esc
    mov ah, 0
    int 0x16
    cmp al, 0x0D
    je .entered
    cmp al, 0x1B
    je .exited
    jmp wait_enter_esc
.entered:
    ret
.exited:
    mov ax, 0x4C00
    int 0x21

DrawFrame:
    ; Draws the frame of the game (top, sides, bottom, corners)
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
    call DrawSnake
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
    ret

.game_over:
	call GameOverScreen

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
    ; Starts the game, initializing the screen and waiting for user input
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov es, ax

    call clrscn
    mov ah,02h
    mov bh,0
    mov dh,10
    mov dl,20
    int 0x10
    mov si, title
    call print_str
    mov ah,02h
    mov bh,0
    mov dh,12
    mov dl,18
    int 0x10
    mov si, prompt
    call print_str
    call wait_enter_esc

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
    
    jmp GameLoop
