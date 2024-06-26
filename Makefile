.PHONY: all run build

all: boot.bin KRNLDR.SYS

boot.bin: ./sys/boot/boot.asm
	nasm -f bin -o build/boot.bin ./sys/boot/boot.asm
KRNLDR.SYS: ./sys/boot/stage2.asm # KRNLDR - kernel loader
	nasm -f bin -o build/KRNLDR.SYS -I ./sys/inc/ ./sys/boot/stage2.asm

run:
	sudo mount ./build/floppy.img /media/floppy1 -t msdos -o "fat=12" -o loop
	qemu-system-x86_64 -fda ./build/floppy.img -enable-kvm
	sudo umount /media/floppy1

run_dbg:
	sudo mount ./build/floppy.img /media/floppy1 -t msdos -o "fat=12" -o loop
	qemu-system-x86_64 -s -fda ./build/floppy.img -enable-kvm
	sudo umount /media/floppy1

floppy.img:
	dd if=/dev/zero of=./build/floppy.img bs=512 count=2880
	mkdosfs -F 12 ./build/floppy.img
	chmod a+w ./build/floppy.img
	sudo mount ./build/floppy.img /media/floppy1 -t msdos -o "fat=12" -o loop
	sudo cp ./build/KRNLDR.SYS /media/floppy1
	sudo umount /media/floppy1
	dd if=./build/boot.bin of=./build/floppy.img conv=notrunc

build: all run
