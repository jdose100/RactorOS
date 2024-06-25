; Примичание: здесь мы выполняем как обычно, .COM, но мы всё ещё находимся
; в кольце 0. Мы будем использовать этот загрузчик для настройки 32-битной
; версии, режим и базовой обработки исключений. Эта загруженная программа
; будет нашим 32-битным ядром. А также у нас сдесь нету ограничения в 512
; байт, поэтому мы можем добавить сюда всё что захотим!
bits 16 ; говорим nasm что будем работать в 16-битном режиме
org 0x0 ; смещение равно 0, сегменты установим позже
jmp main ; прыгаем в main мимо блоков

; ******* ;
; ФУНКЦИИ ;
; ******* ;

Print: ; печатает строку; ds => si: 0 - конец строки
    lodsb ; загружает следующий байт строки от si в al
    or al, al ; al == 0?
    jz .done ; если да то прыгаем в done
    mov ah, 0eh ; нет, печатаем символ
    int 10h
    jmp Print
.done: 
    ret ; конец, выходим из функции

; ************ ;
; ФУНКЦИЯ MAIN ;
; ************ ;

main:
    cli ; очищаем прерывания
    push cs ; перемещаем через стек cs в ds
    pop ds

    mov si, hello_msg ; в si строку которую печатаем
    call Print ; вызываем печать

    ; отключаем систему
    cli ; очищаем прерывания
    hlt ; останавливаем систему

; ************** ;
; СЕГМЕНТ ДАННЫХ ;
; ************** ;
hello_msg: db "Preparing to load operating system...", 13, 10, 0

