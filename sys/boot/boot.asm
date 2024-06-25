; ***************************** ;
; ЗАГРУЗЧИК СИСТЕМЫ "RACTOR OS" ;
; ***************************** ;
bits 16 ; указываем nasm что код 16-битный

org 0 ; настроим рагистры в main
start: jmp main ; прыгаем мимо блоков к загрузчику

; ******************* ;
; БЛОК ПАРАМЕТРОВ OEM ;
; ******************* ;
bpbOEM:               db "RactorOS" ; имя ос, ТОЛЬКО 8 БАЙТ!
bpbBytesPerSector:    dw 512
bpbSectorsPerCluster: db 1
bpbReservedSectors:   dw 1
bpbNumberOfFATs:      db 2
bpbRootEntries:       dw 224
bpbTotalSectors:      dw 2880
bpbMedia:             db 0xF8
bpbSectorsPerFAT:     dw 9
bpbSectorsPerTrack:   dw 18
bpbHeadsPerCylinder:  dw 2
bpbHiddenSectors:     dd 0
bpbTotalSectorsBig:   dd 0
bsDriveNumber:        db 0
bsUnused:             db 0
bsExtBootSignature:   db 0x29
bsSerialNumber:       dd 0xa0a1a2a3
bsVolumeLabel:        db "MOS FLOPPY "
bsFileSystem:         db "FAT12   "

; ****************** ;
; ФУНКЦИИ ЗАГРУЗЧИКА ;
; ****************** ;

; ******************************
; печатает строку
; DS => SI: 0 завершаемая строка
; ******************************

Print:
    lodsb
    or al, al ; al = текущий символ
    jz .done ; если al == 0, значит конец строки
    mov ah, 0eh ; получить следующий символ
    int 10h ; вызываем прерывание - ВЫХОД ВИДЕОТЕЛЕТАЙПА
    jmp Print ; прыгаем в начало
.done:
    ret ; функция закончилась, выходим

; ********************************
; читает серию секторов
; cx => кол-во секторов для чтения
; ax => начало сектора
; es:bx => буфер для чтения
; ********************************

ReadSectors:
    mov di, 0x0005 ; 5 попыток до ошибки
.SECTOR_LOOP:
    push ax
    push bx
    push cx

    call LBACHS ; конвертируем стартовы сектор в CHS

    mov ah, 0x02 ; функция биоса на чтение сектора
    mov al, 0x01 ; чтение 1 сектора
    mov ch, byte [absoluteTrack]
    mov cl, byte [absoluteSector] ; сектор
    mov dh, byte [absoluteHead] ; головка
    mov dl, byte [bsDriveNumber] ; номер дисковода
    
    int 0x13 ; вызов биоса
    jnc .SUCCESS ; проверка на ошибку чтения
    xor ax, ax ; диск сбоса биоса
    int 0x13 ; вызов биоса
    
    dec di ; декремент счётчика ошибок
    pop cx
    pop bx
    pop ax

    jnz .SECTOR_LOOP ; попытка прочитать ещё раз
    int 0x18
.SUCCESS:
    mov si, msgProgress
    call Print
    pop cx
    pop bx
    pop ax
    add bx, word [bpbBytesPerSector] ; очередь в следующий буфер
    inc ax ; очередь в следующий сектор
    loop ReadSectors ; читаем следующий сектор
    ret

; *****************************************
; конвертируем CHS в LBA
; LBA = (кластер - 2) * секторов на кластер
; *****************************************

ClusterLBA:
    sub ax, 0x0002 ; нулевой, базовый номер кластера
    xor cx, cx
    mov cl, byte [bpbSectorsPerCluster] ; ковертируем байт в слово
    mul cx
    add ax, word [datasector] ; базовый сектор данных
    ret

; *******************************************************************************
; конвертирует LBA в CHS
; ax => LBA адрес для конвертации
;
; абсолютный сектор = (логический сектор / секторов на дорожку) + 1
; абсолютная головка = (логический сектор / секторов на дорожку) MOD кол-во голов
; абсолютная дорожка = логический сектор / (секторов на дорожку * колв-о голов)
; *******************************************************************************

LBACHS:
    xor dx, dx ; подготовка dx:ax для операций
    div word [bpbSectorsPerTrack] ; вычисляем
    inc dl ; корректировка для сектора 0
    mov byte [absoluteSector], dl

    xor dx, dx ; подготовка dx:ax для операций
    div word [bpbHeadsPerCylinder] ; вычисляем
    mov byte [absoluteHead], dl
    mov byte [absoluteTrack], al
    ret

; ************************** ;
; СТАРТОВАЯ ТОЧКА ЗАГРУЗЧИКА ;
; ************************** ;

main: ; загрузчик
    ; код, расположенный по аддресу 0000:7C00
    ; отрегулируйе регистры сегменты

    cli ; запрещаем прерывания
    mov ax, 0x07C0 ; настраиваем регистры на точку вашего сегмента
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; создаём стек
    mov ax, 0x0000 ; устанавливаем адрес стека
    mov ss, ax
    mov sp, 0xFFFF
    sti ; восстанавливаем прерывания

    ; пишем сообщение о загрузке
    mov si, msgLoading
    call Print

LOAD_ROOT: ; загружаем таблицу корневых каталогов
    ; вычислить размер корневого каталога и сохранить в cx
    xor cx, cx
    xor dx, dx
    mov ax, 0x0020 ; 32-битная запись каталога
    mul word [bpbRootEntries] ; общий размер каталога
    div word [bpbBytesPerSector] ; сектора используемые каталогом
    xchg ax, cx

    ; вычислить рамположение корневого каталога и сохранить в ax
    mov al, byte [bpbNumberOfFATs] ; кол-во fat
    mul word [bpbSectorsPerFAT] ; сектора используемые fat
    add ax, word [bpbReservedSectors] ; настроить загрузочный сектор
    mov word [datasector], ax ; база корневого каталога
    add word [datasector], cx

    ; прочитать корневой каталог в память (7C00:0200)
    mov bx, 0x0200 ; скопировать корневой каталог выше загрузочного сектора
    call ReadSectors
    
    ; **************
    ; найти 2 стадию
    ; **************

    ; посмотреть корневой каталог на наличие двоичного образа
    mov cx, word [bpbRootEntries] ; счётчик цикла загрузки
    mov di, 0x0200 ; найти первую корневую запись
.loop:
    push cx
    mov cx, 0x000B
    mov si, ImageName ; название файла который нужно найти
    push di
    rep cmpsb ; тест на входное совпадение
    pop di
    je LOAD_FAT
    pop cx
    add di, 0x0020 ; поставить в очередь следующую запись каталога
    loop .loop
    jmp FAILURE 

LOAD_FAT: ; загружаем fat
    ; сохраняем стартовый кластер загрузочного образа
    mov si, msgCRLF
    call Print
    mov dx, word [di + 0x001A]
    mov word [cluster], dx ; первый файл кластера

    ; вычисляем размер fat и сохраняем его в cx
    xor ax, ax
    mov al, byte [bpbNumberOfFATs] ; кол-во fats
    mul word [bpbSectorsPerFAT] ; сектора используемые fat
    mov cx, ax

    ; вычисляем расположение fat и сохраняем его в ax
    mov ax, word [bpbReservedSectors] ; настраиваем на загрузочный сектор

    ; читаем fat в память (7C00:0200)
    mov bx, 0x0200 ; копируем fat мимо загрузочного кода
    call ReadSectors

    ; читаем файл в память (0050:0000)
    mov si, msgCRLF
    call Print
    mov ax, 0x0050
    mov es, ax     ; место куда читать
    mov bx, 0x0000 ; место куда читать
    push bx

LOAD_IMAGE: ; загружаем загрузчик 2 стадии
    mov ax, word [cluster] ; кластер для чтения
    pop bx ; буффер для чтения
    call ClusterLBA ; конвертируем кластер в LBA
    xor cx, cx
    mov cl, byte [bpbSectorsPerCluster] ; секторы для чтения
    call ReadSectors
    push bx

    ; вычисляем следующий кластер
    mov ax, word [cluster] ; определяем текущий кластер
    mov cx, ax ; копируем текущий кластер
    mov dx, ax ; копируем текущий кластер
    shr dx, 0x0001 ; делим на 2
    add cx, dx ; сумма за (3/2)
    mov bx, 0x0200 ; расположение fat в памяти
    add bx, cx ; индекс в fat
    mov dx, word [bx] ; читаем 2 байта из fat
    test ax, 0x0001
    jnz .ODD_CLUSTER
.EVEN_CLUSTER:
    and dx, 0000111111111111b ; берём младшие 12 бит
    jmp .DONE
.ODD_CLUSTER:
    shr dx, 0x0004 ; берём старшие 12 бит
.DONE:
    mov word [cluster], dx ; сохраняем новый кластер
    cmp dx, 0x0FF0 ; тест на конец файла
    jb LOAD_IMAGE

DONE:
    mov si, msgCRLF
    call Print
    push word 0x0050
    push word 0x0000
    retf

FAILURE:
    mov si, msgFailure
    call Print
    mov ah, 0x00
    int 0x16 ; ждём нажатия клавиши
    int 0x19 ; перезагружаемся

; ************************* ;
; СЕГМЕНТ ДАННЫХ ЗАГРУЗЧИКА ;
; ************************* ;

; для fat12
absoluteSector: db 0x00
absoluteHead:   db 0x00
absoluteTrack:  db 0x00 
datasector:     dw 0x0000
cluster:        dw 0x0000
ImageName:      db "STAGE2  SYS"
msgLoading:     db 0x0D, 0x0A, "Loading Boot Image ", 0x0D, 0x0A, 0x00
msgCRLF:        db 0x0D, 0x0A, 0x00
msgProgress:    db "*", 0x00
msgFailure:     db 0x0D, 0x0A, "ERROR : Press Any Key to Reboot", 0x0A, 0x00

; У нас должно быть ровно 512 байт, поэтому занимаем пустое
; пространство нулями, но оставляем 2 байта для загрузочной подписи
times 510 - ($-$$) db 0
dw 0xAA55 ; загрузочная подпись
