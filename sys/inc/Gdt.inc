; ********************* ;
; Gdt.inc               ;
;         - функции GDT ;
; RactorOS              ;
; ********************* ;

%ifndef __GDT_INC_123ABC_INCLUDED__
%define __GDT_INC_123ABC_INCLUDED__
bits 16

; ***************************
; InstallGDT()
;             - установка gdt
; ***************************

InstallGDT:
    cli ; очищаем прерывания
    pusha ; сохраняем регистры
    lgdt [toc] ; загружаем gdt в gdtr
    sti ; разрешаем прерывания
    popa ; восстанавливаем регистры
    ret ; выходим

; ***************************** ;
; Global Desctiptor Table (GDT) ;
; ***************************** ;

gdt_data:
    dd 0 ; нулевой дескриптор
    dd 0
; gdt_code - дескриптор кода
    dw 0FFFFh ; нижний предел
    dw 0 ; нижний базовый
    db 0 ; средний базовый
    db 10011010b ; доступ
    db 11001111b ; детализация
    db 0 ; высший базовый  
; gdt_data - дескриптор данных
    dw 0FFFFh ; нижний предел то же, что и у кода
    dw 0 ; нижний базовый
    db 0 ; средний базовый
    db 10011010b ; доступ
    db 11001111b ; детализация
    db 0 ; высший базовый

end_of_gdt:
toc:
    dw end_of_gdt - gdt_data - 1 ; лимит (размер gdt)
    dd gdt_data

%endif ; __GDT_INC_123ABC_INCLUDED__
