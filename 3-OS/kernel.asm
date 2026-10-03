[org 0x7E00]

jmp main
msg db "Hello, Kernel!", 0
disk_fail db "DRF", 0
file db "test.txt", 0
file_in db "", 0

print:
    lodsb
    cmp al, 0
    je .done

    mov ah, 0x0e
    int 0x10
    jmp print

.done:
    ret

main:
    mov [boot_drive], dl    ; Save the BIOS drive number right away!
    
    mov ax, 2               ; LBA 2 (3rd sector for test.txt)
    call lba_to_chs

    ; --- Step 4 & 5: Set RAM buffer and read parameters ---
    xor ax, ax              ; AX = 0 for ES
    mov es, ax
    mov bx, 0x8000          ; Destination buffer at 0x8000

    mov ah, 0x02            ; BIOS Read function
    mov al, 0x01            ; Read 1 sector
    mov dl, [boot_drive]    ; Restore correct drive number

    int 0x13
    jc disk_error

    mov ax, 0
    mov ds, ax
    mov si, 0x8000
    call print
    
    ; --- Step 1: Zero-out 512 bytes at 0x9000 to ensure a clean sector ---
    xor ax, ax
    mov es, ax              ; ES = 0
    mov di, 0x9000          ; Start of buffer
    mov cx, 256             ; 256 words = 512 bytes
    xor ax, ax
    rep stosw               ; Fill 0x9000 to 0x9200 with zeros

    ; --- Step 2: Copy "Hello, World! " 5 times into 0x9000 ---
    mov di, 0x9000          ; Reset destination to start
    mov cx, 5               ; Repeat 5 times

.copy_loop:
    push cx
    mov si, write_msg       ; Source string
.inner_copy:
    lodsb
    cmp al, 0
    je .next_repeat
    stosb                   ; Store byte in ES:DI
    jmp .inner_copy

.next_repeat:
    pop cx
    dec cx
    jnz .copy_loop

    ; --- Step 3: Write to LBA 3 (Sector 4) ---
    mov ax, 3               ; LBA 3
    mov bx, 0x9000          ; Source buffer at 0x9000
    call write_sector       

    ; --- Step 4: Read it back from LBA 3 to 0x8000 to verify ---
    mov ax, 3               ; LBA 3
    mov bx, 0x8000          ; Read destination buffer at 0x8000
    call read_sector        

    ; --- Step 5: Print what we read back ---
    mov ax, 0
    mov ds, ax
    mov si, 0x8000
    call print
    jmp $

lba_to_chs:
    push bx
    push ax

    ; Step 1: Sector = (LBA % SectorsPerTrack) + 1
    xor dx, dx
    mov bp, 18          
    div bp              
    inc dx              
    mov cl, dl          

    ; Step 2: Track quotient is in AX. Cylinder = Track / Heads, Head = Track % Heads
    xor dx, dx
    mov bp, 2           
    div bp              
    
    mov ch, al          
    mov dh, dl          

    pop ax
    pop bx
    ret

disk_error:
    mov si, disk_fail
    call print
    ret

write_sector:
    ; Inputs: AX = LBA, BX = Buffer address
    push ax                 ; Save LBA
    push bx                 ; Save Buffer address
    
    call lba_to_chs         ; Converts LBA in AX to CH, CL, DH

    pop bx                  ; RESTORE BX = buffer address (0x9000)
    add sp, 2               ; Clear the saved AX from stack (we don't need LBA anymore)

    xor ax, ax
    mov es, ax              ; ES = 0
    mov ah, 0x03            ; BIOS Write Sectors function
    mov al, 0x01            ; Write 1 sector
    mov dl, [boot_drive]    ; Ensure correct drive number

    int 0x13                ; Call BIOS disk interrupt
    jc write_error          
    ret

read_sector:
    ; Inputs: AX = LBA, BX = Buffer address
    push ax                 
    push bx                 

    call lba_to_chs         

    pop bx                  ; RESTORE BX = buffer address (0x8000)
    add sp, 2               

    xor ax, ax
    mov es, ax              
    mov ah, 0x02            ; BIOS Read Sectors function
    mov al, 0x01            ; Read 1 sector
    mov dl, [boot_drive]    

    int 0x13                
    jc disk_error
    ret

write_error:
    mov si, write_fail_msg
    call print
    jmp $

write_fail_msg db "Disk Write Failed", 0    ; Disk Write Failed
write_msg db "Hello, World! ", 0
boot_drive db 0             ; Variable stored safely inside the 512-byte block

times 510-($-$$) db 0       ; Pads the kernel to EXACTLY 512 bytes