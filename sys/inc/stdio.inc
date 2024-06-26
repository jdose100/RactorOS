; ********************************* ;
; stdio.inc                         ;
;          - Процедуры Ввода/Вывода ;
; RactorOS                          ;
; ********************************* ;
%ifndef __STDIO_INC_612AF3B3_INCLUDED__
%define __STDIO_INC_612AF3B3_INCLUDED__
bits 16

; ************************************************ ;
; Puts16() - печатает строку заканчивающиеся нулём
; ds => si: 0, конец строки
; ************************************************ ;

Puts16:
    pusha ; сохраняем регистры
.loop:
    lodsb ; загружаем следующий байт строки из si в al
    or al, al ; al == 0?
    jz __Puts16_done ; да, конец строки
    mov ah, 0eh ; нет, печатаем дальше
    int 10h ; вызов биоса
    jmp .loop
__Puts16_done:
    popa ; восстанавливаем регисры
    ret ; выходим


%endif ; __STDIO_INC_612AF3B3_INCLUDED__
