.PHONY: all run build

all: boot.bin STAGE2.SYS

boot.bin: ./sys/boot/boot.asm
	nasm -f bin ./sys/boot/boot.asm -o build/boot.bin
STAGE2.SYS: ./sys/boot/stage2.asm
	nasm -f bin ./sys/boot/stage2.asm -o build/STAGE2.SYS

run:
	sudo mount ./build/floppy.img /media/floppy1 -t msdos -o "fat=12" -o loop
	qemu-system-x86_64 -fda ./build/floppy.img -m 2048K -enable-kvm
	sudo umount /media/floppy1

floppy.img:
	dd if=/dev/zero of=./build/floppy.img bs=512 count=2880
	mkdosfs -F 12 ./build/floppy.img
	chmod a+w ./build/floppy.img
	sudo mount ./build/floppy.img /media/floppy1 -t msdos -o "fat=12" -o loop
	sudo cp ./build/stage2.sys /media/floppy1
	sudo umount /media/floppy1
	dd if=./build/boot.bin of=./build/floppy.img conv=notrunc

build: all run
