DEST?=.
ARMGNU?=riscv64-linux-gnu

AOPS = --warn --fatal-warnings

all : mecrisp-quintus-ch32v203g6.bin

mecrisp-quintus-ch32v203g6.o : mecrisp-quintus-ch32v203g6.s terminal.s flash.s interrupts.s
	$(ARMGNU)-as -g mecrisp-quintus-ch32v203g6.s -o mecrisp-quintus-ch32v203g6.o -march=rv32im

mecrisp-quintus-ch32v203g6.bin : memmap mecrisp-quintus-ch32v203g6.o
	$(ARMGNU)-ld -o mecrisp-quintus-ch32v203g6.elf -T memmap mecrisp-quintus-ch32v203g6.o -m elf32lriscv && \
	$(ARMGNU)-objdump -Mnumeric -D mecrisp-quintus-ch32v203g6.elf -j .text > mecrisp-quintus-ch32v203g6.list && \
	$(ARMGNU)-objcopy mecrisp-quintus-ch32v203g6.elf mecrisp-quintus-ch32v203g6.bin -O binary && \
	$(ARMGNU)-objcopy mecrisp-quintus-ch32v203g6.elf mecrisp-quintus-ch32v203g6.hex -O ihex

clean:
	rm -f *.bin
	rm -f *.hex
	rm -f *.o
	rm -f *.elf
	rm -f *.list
