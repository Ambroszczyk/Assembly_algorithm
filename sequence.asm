SYS_READ    equ 0
SYS_OPEN    equ 2
SYS_CLOSE   equ 3
SYS_EXIT    equ 60
BUFFER_SIZE equ 8192
O_RDONLY	equ 0
;Constant different from zero.
NOT_ZERO    equ 1

;*********************************USED TERMS************************************
;numbers block -- block of numbers between two consecutive zeros. 

global _start

section .bss
;buffer to save data. Used to decrease the number of syscalls.
buffer resb BUFFER_SIZE 
;During iterating over non first numbers block, we put read numbers into
;this array.
current_numbers_set resb 256
file_descriptor resq 1

section .data
;Array holding information which numbers have been read. The idea is the same as
;in the bucket sort algorithm. 
first_block_numbers times 256 db 0
;Counter says how many numbers were read in the first block.
first_block_counter db 0


;******************************REGISTERS MEANING********************************
;r8 -- used to take number from number current_numbers_set.
;r12 -- says how many non zero numbers were read in the current numbers block.
;r13 -- register for load_number function, r13 = 0 means that we haven't
;read any zero yet.
;r14 -- register keeps information whether last read number was equal zero. 
;If pointed situation occurred r14 = 0, r14 = NOT_ZERO in the other case.
;rbx -- holds information how many bytes have been saved in the buffer after 
;read_file function call.
;r15 -- iterator over numbers in nested_loop. Preserves 0 <= r15 < rbx.


;************************************IDEA***************************************
;First of all, we read first numbers block and for each number x we set
;[first_block_numbers + x]= 1. When we are in a non first numbers block for each
;number x we make following steps:
;   1. check if [first_block_number + x] = 1
;   2. set [first_block_number + x] = 0
;   3. put x into current_numbers_set 
;At the end of a current numbers block (i.e. when we read zero) we take numbers 
;from current_numbers_set and for each number x we set
;[first_block_number + x] = 1. To make program faster we use buffer array.
;If any error happens program jumps into exit_error label. 

;**********************************FUNCTIONS************************************
section .text

;Function supposes that the file name is in the rdi register.
open_file: 
    mov rax, SYS_OPEN
    mov rsi, O_RDONLY
    syscall
    ret

;Function supposes that the descriptor is saved in the file_descriptor variable.
read_file: 
    mov rdi, [file_descriptor]
    mov rax, SYS_READ
    mov rsi, buffer
    mov rdx, BUFFER_SIZE
    syscall
    ret

;Function supposes that the descriptor is saved in the file_descriptor variable.
close_file:
    mov rax, SYS_CLOSE
    mov rdi, [file_descriptor]
    syscall
    ret

;The core of the program. Function is responsible for verifying whether sequence
;is correct.
load_number:
    cmp dil, 0
    je load_number_zero ;Jump if zero was read.

load_number_not_zero:
    mov r14, NOT_ZERO ;Set last number was not zero.

    cmp r13, 0 
    je load_number_first_block ;Jump if we are in the first numbers block.

    ;At this moment we know that we read non zero number and we are not inside 
    ;the first numbers block.
    cmp byte [first_block_numbers + edi], 1
    jne exit_error;If number did not appear in the first numbers block, 
    ;return error.

    mov byte [first_block_numbers + edi], 0 ;Mark as visited.
    mov byte [current_numbers_set + r12d], dil ;Put used number into array.
    inc r12 ;Increase counter of the numbers in the current block.
    ret

load_number_first_block:
    cmp byte [first_block_numbers + edi], 1 
    je exit_error ;If in the first numbers block are duplicates, return error.
    mov byte [first_block_numbers + edi], 1 ;Set number as visited.
    inc byte [first_block_counter]
    ret

load_number_zero:
    xor r14, r14 ;Zero was read so set r14 = 0; 
    cmp r13, 0 
    je load_number_first_zero ;If we haven't read any 0 yet, jump to first zero.
    
    ;At this moment we know that we read number from a non first block block.
    cmp r12b, [first_block_counter] 
    jne exit_error ;If some number was not used return error. 

    jmp load_number_mini_loop_condition ;Start from condition.
load_number_mini_loop_body:
    xor r8, r8
    mov r8b, byte [current_numbers_set + r12d - 1] ;Take read number.
    mov byte [first_block_numbers + r8d], 1 ;Restore information about the
    ;first block.
    dec r12
load_number_mini_loop_condition:
    cmp r12, 0
    jne load_number_mini_loop_body ;End loop when r12 = 0.
    ret  

load_number_first_zero:
    mov r13, NOT_ZERO ;Set that first zero occurred.
    ret

;*************************************MAIN**************************************
_start:
    pop rax
    cmp rax, 2 ;Check how many arguments were put. If number != 2 return error. 
    jne exit_error 
    pop rdi ;Pop useless program's name.
    pop rdi ;Get useful file's name.

    call open_file

    mov [file_descriptor], rax ;Save file descriptor.
    xor r12, r12 ;Set r12 = 0.
    xor r13, r13 ;Set r13 = 0.
    mov r14, NOT_ZERO ;Set r14 != 0.

loop_body: 
    call read_file ;Read BUFFER_SIZE bytes from the file.
    mov rbx, rax ;Transfer amount of read bytes to the rbx register.
    xor r15, r15 ;r15 starts from 0.

    jmp nested_loop_condition ;Start from loop condition.
nested_loop_body: ;Iterates over read numbers.
    xor rdi, rdi ;Set rdi = 0.
    mov dil, [buffer + r15d] ;Save number in the last byte of the rdi register.
    call load_number ;Run this function to work on the read number.
    inc r15
nested_loop_condition:
    cmp r15, rbx
    jb nested_loop_body ;If r15 < rbx jumps to the nested_loop_body.

loop_condition:
    cmp rbx, BUFFER_SIZE
    je loop_body ;If data fulfilled buffer, i.e. rbx = BUFFER_SIZE, jump to 
    ;the loop_body.

    cmp r14, 0 
    jne exit_error ;Check if the last read number was zero, if was not
    ;return error.

exit_good:
    call close_file
    xor edi, edi ;Exit code = 0;
    jmp exit  
exit_error:
    call close_file
    mov edi, 1  ;Exit code = 1;
;close_file can not be called from exit because it modifies rdi register.
exit:    
    mov eax, SYS_EXIT
    syscall


