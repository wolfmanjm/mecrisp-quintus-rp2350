
ARMGNU?=riscv64-linux-gnu
ASFLAGS?=-march=rv32im_zbs

AOPS = --warn --fatal-warnings

all : mecrisp-quintus-rp2350.bin

mecrisp-quintus-rp2350.o : mecrisp-quintus-rp2350.s
	$(ARMGNU)-as mecrisp-quintus-rp2350.s -o mecrisp-quintus-rp2350.o $(ASFLAGS)

mecrisp-quintus-rp2350.bin : memmap mecrisp-quintus-rp2350.o
	$(ARMGNU)-ld -o mecrisp-quintus-rp2350.elf -T memmap mecrisp-quintus-rp2350.o -m elf32lriscv
	$(ARMGNU)-objdump -Mnumeric -D mecrisp-quintus-rp2350.elf > mecrisp-quintus-rp2350.list
	$(ARMGNU)-objcopy mecrisp-quintus-rp2350.elf mecrisp-quintus-rp2350.bin -O binary

clean:
	rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list
