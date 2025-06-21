trampoline_trap:  # In case the Forth definition returns, catch execution here.
	.equ BOOTROM_ENTRY_OFFSET, 0x7dfc
    li a0, BOOTROM_ENTRY_OFFSET + 32 * 1024
    la a1, 1f
    csrw mtvec, a1
    jr a0
    # Go here if we trapped:
.p2align 2
1:  li a0, BOOTROM_ENTRY_OFFSET
    jr a0
  	# should not get here
	j trampoline_trap
