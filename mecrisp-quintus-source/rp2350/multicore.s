
# -----------------------------------------------------------------------------
  Definition Flag_visible, "mhartid@" # Which core is this running on?
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mhartid, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "execute-coprocessor"
execute_coprocessor: # ( xt -- ) Entry point for the coprocessor trampoline
# -----------------------------------------------------------------------------

  push x1

  # Store the execution token into a global variable
  li x14, trampolineaddr # Note we are using li here as we forcefully circumvent the linker facilities
  sw x8, 0(x14)
  drop

  # Launcher code running on core 0 here...
  # This actually launches the coprocessor_trampoline.

  # Deactivate interrupts, because C code might "disconnect" the data stack pointer.
  # Also save x3 to x13 before calling into C

  call eintq # Are interrupts enabled?
    csrrci zero, mstatus, 8 # Clear Machine Interrupt Enable Bit

  call stop_core1
  call launch_core1

  popda x15 # Do we need to reenable interrupts?
  beq x15, zero, 1f
    csrrsi zero, mstatus, 8 # Set Machine Interrupt Enable Bit
1:pop x1
  ret


# -----------------------------------------------------------------------------
  Definition Flag_visible, "stop-coprocessor"
stop_coprocessor: # ( -- )
# -----------------------------------------------------------------------------

  push x1

  # Stop code running on core 0 here...

  # Deactivate interrupts, because C code might "disconnect" the data stack pointer.
  # Also save x3 to x13 before calling into C

  call eintq # Are interrupts enabled?
    csrrci zero, mstatus, 8 # Clear Machine Interrupt Enable Bit

  call stop_core1

  popda x15 # Do we need to reenable interrupts?
  beq x15, zero, 1f
    csrrsi zero, mstatus, 8 # Set Machine Interrupt Enable Bit
1:pop x1
  ret


# -----------------------------------------------------------------------------
  Definition Flag_visible, "trampoline-xt"
  # ( -- addr ) # Make the global variable visible for Forth. Just for testing, will be removed later
# -----------------------------------------------------------------------------
  pushdatos
  li x8, trampolineaddr
  ret

# -----------------------------------------------------------------------------
coprocessor_trampoline: # Runs on the second core now
# -----------------------------------------------------------------------------

  # No need to save registers, as we have no valid Forth context on core 1 yet.

  # Core 1 initialisations here if necessary...

  # Start cycle counter
  csrrwi zero, 0x320, 4  # MCOUNTINHIBIT: Keep minstret(h) stopped, but run mcycle(h).

  # Disable interrupts
  csrrci zero, mstatus, 8 # Clear Machine Interrupt Enable Bit

  # Initialise the registers for the Forth definition to run:

  li x2, returnstackcore1begin # Initialise return stack
  li x9, datastackcore1begin   # Initialise data   stack
  li x8, 42                   # TOS is initially set to 42 as a "stack canary", but not stictly necessary

  li x14, trampolineaddr       # Address of global variable (no linker here, use li)
  lw x14, 0(x14)               # Fetch entry point from global variable
  jalr x1, x14, 0              # Execute it

trampoline_trap:  # In case the Forth definition returns, catch execution here.
  slt x0, x0, x0 # WFE h3.block
  j trampoline_trap

# Alternative that puts core 1 back into the bootup state by launching it into the BOOTROM:

#  trampoline_trap:  # In case the Forth definition returns, catch execution here.
#      .equ BOOTROM_ENTRY_OFFSET, 0x7dfc
#      li a0, BOOTROM_ENTRY_OFFSET + 32 * 1024
#      la a1, 1f
#      csrw mtvec, a1
#      jr a0
#      # Go here if we trapped:
#  .p2align 2
#  1:  li a0, BOOTROM_ENTRY_OFFSET
#      jr a0
#      # should not get here
#      j trampoline_trap

# -----------------------------------------------------------------------------
# x0 zero 		Hard-wired zero —
# x1 ra 		Return address Caller
# x2 sp 		return stack Stack pointer Callee
# x3 gp 		loop index
# x4 tp 		loop limit
# x5–7 t0–2 	Scratch register, needs to be saved.
# x8 s0/fp 		TOS
# x9 s1 		PSP Set data stack pointer
# x10–13 a0–3 	Scratch register, needs to be saved.
# x14–17 a4–7 	Free scratch register, not saved across calls.
# x18–27 s2–11 	Free scratch register, not saved across calls.
# x28–31 t3–6 	Free scratch register, not saved across calls.

# save these in my calls
# x3=gp, x4=tp, x5=t0, x6=t1, x7=t2, x8=s0, x9=s1, x10=a0, x11=a1, x12=a2, x13=a3
# -----------------------------------------------------------------------------

# this is data handed off to bootrom to start core1
.p2align 4
core1_sp:
	.dcb.b 256
core1_sp_end:
	.word 0
cmd_sequence:
	.word 0
	.word 0
	.word 1
	.word __VECTOR_TABLE
	.word core1_sp_end
core1_entry:
	.word 0 # entry
cmd_sequence_end:
	.word 0

# bootrom seems to need a vector table for core1 (Maybe not, no way to tell)
.p2align 6
__VECTOR_TABLE:
# Hardware vector table for standard RISC-V interrupts, indicated by `mtvec`.
.option push
.option norvc
.option norelax
j isr_riscv_machine_exception
.word 0
.word 0
j isr_riscv_machine_soft_irq
.word 0
.word 0
.word 0
j isr_riscv_machine_timer
.word 0
.word 0
.word 0
j isr_riscv_machine_external_irq
.option pop

isr_riscv_machine_exception: j isr_riscv_machine_exception
isr_riscv_machine_soft_irq: j isr_riscv_machine_soft_irq
isr_riscv_machine_timer: j isr_riscv_machine_timer
isr_riscv_machine_external_irq: j isr_riscv_machine_external_irq

# Register definitions used below
.equ SIO_BASE, 0xd0000000
.equ _SIO_FIFO_ST, 0x050
.equ _SIO_FIFO_WR, 0x054
.equ _SIO_FIFO_RD, 0x058

.equ SIO_FIFO_ST_VLD_BITS, 0x00000001
.equ SIO_FIFO_ST_RDY_BITS, 0x00000002

.equ PSM_BASE, 0x40018000
  .equ _FRCE_ON, 0x00000000
    .equ b_FRCE_ON_PROC1, 1<<24
  .equ _FRCE_OFF, 0x00000004
    .equ b_FRCE_OFF_PROC1, 1<<24
    .equ o_FRCE_OFF_PROC1, 24
 .equ _DONE, 0x0000000c
    .equ b_DONE_PROC1, 1<<24

.equ WRITE_NORMAL, (0x0000)   # Normal read write access
.equ WRITE_XOR   , (0x1000)   # Atomic XOR on write
.equ WRITE_SET   , (0x2000)   # Atomic bitmask set on write
.equ WRITE_CLR   , (0x3000)   # Atomic bitmask clear on write

.equ SIO_IRQ_FIFO, 25 # Select SIO's IRQ_FIFO output


.equ RVCSR_MEIEA_OFFSET, 0x00000be0
.equ RVCSR_MEIFA_OFFSET, 0x00000be2
.equ RVCSR_MIE_MEIE_BITS,  0x00000800
.equ RVCSR_MSTATUS_MIE_BITS,  0x00000008

# enable/disable (a1=1|0) the irq specified in a0
enable_irq:
		# irq_set_mask_n_enabled(num / 32, 1u << (num % 32), enabled);
        # hazard3_irqarray_clear(RVCSR_MEIFA_OFFSET, 2 * n, mask & 0xffffu);
        # hazard3_irqarray_clear(RVCSR_MEIFA_OFFSET, 2 * n + 1, mask >> 16);
        # hazard3_irqarray_set(RVCSR_MEIEA_OFFSET, 2 * n, mask & 0xffffu);
        # hazard3_irqarray_set(RVCSR_MEIEA_OFFSET, 2 * n + 1, mask >> 16);
    srli t0, a0, 5  		# n
    slli t0, t0, 1			# 2*n
    andi t1, a0, 31 	# mask
    bset t1, zero, t1 	# bitset
	slli t2, t1, 16				# upper 16 bits are bit to set (mask),
	or t2, t2, t0 				# lower 5 bits are the window (n)
    beqz a1, 1f
	csrc RVCSR_MEIFA_OFFSET, t2
	csrs RVCSR_MEIEA_OFFSET, t2 # enable
	j 2f
1:	csrc RVCSR_MEIEA_OFFSET, t2 # disable
2:	srli t2, t1, 16
	addi t0, t0, 1
	slli t2, t2, 16				# upper 16 bits are bit to set (mask),
	or t2, t2, t0 				# lower 5 bits are the window (n)
    beqz a1, 1f
	csrc RVCSR_MEIFA_OFFSET, t2
	csrs RVCSR_MEIEA_OFFSET, t2
	j 2f
1: 	csrc RVCSR_MEIEA_OFFSET, t2
2:	ret

# feeds the FIFO to get he bootrom to start up core1
launch_core1:
	pushregs

	# core1 will run the coprocessor_trampoline code above
	# and initially use the stack above but trampoline will fix that
	la t0, core1_entry
	la t1, coprocessor_trampoline
	sw t1, 0(t0)

	# disable FIFO IRQ
1:	li a0, SIO_IRQ_FIFO
	li a1, 0
	call enable_irq

	li t3, SIO_BASE
	# send sequence to core1
ta:	la t0, cmd_sequence
1:	lw t2, 0(t0)
	bnez t2, 3f

	# drain fifo
2:	lw t4, _SIO_FIFO_ST(t3)
	andi t4, t4, SIO_FIFO_ST_VLD_BITS
	beqz t4, 3f
	lw t4, _SIO_FIFO_RD(t3)
	slt x0, x0, x1  	# SEV h3.unblock
	j 2b

	# wait for room in FIFO
3:	lw t4, _SIO_FIFO_ST(t3)
	andi t4, t4, SIO_FIFO_ST_RDY_BITS
	beqz t4, 3b

	# write cmd to core1 fifo
	sw t2, _SIO_FIFO_WR(t3)
	slt x0, x0, x1  	# SEV h3.unblock

	# wait for response
4:	lw t4, _SIO_FIFO_ST(t3)
	andi t4, t4, SIO_FIFO_ST_VLD_BITS
	bnez t4, 5f
	slt x0, x0, x0  	# WFE h3.block
	j 4b

	# read response and compare with what we sent
5:	lw t4, _SIO_FIFO_RD(t3)
	bne t4, t2, ta   			# move to next state on correct response (echo-d value) otherwise start over
	addi t0, t0, 4 				# seq+=4
	la t4, cmd_sequence_end
	bne t0, t4, 1b

	# we are done and core1 should be running now
	popregs
	ret

# this will force core1 to stop, and reset
stop_core1:
	pushregs

	li t0, PSM_BASE|WRITE_SET
	li t1, b_FRCE_OFF_PROC1
	sw t1, _FRCE_OFF(t0)
	li t0, PSM_BASE
1:	lw t1, _FRCE_OFF(t0)
	bexti t1, t1, o_FRCE_OFF_PROC1
	beqz t1, 1b
	# disable FIFO IRQ
	li a0, SIO_IRQ_FIFO
	li a1, 0
	call enable_irq
	li t0, PSM_BASE|WRITE_CLR
	li t1, b_FRCE_OFF_PROC1
	sw t1, _FRCE_OFF(t0)
	# wait for response
	li t0, SIO_BASE
2:	lw t1, _SIO_FIFO_ST(t0)
	andi t1, t1, SIO_FIFO_ST_VLD_BITS
	bnez t1, 3f
	slt x0, x0, x0  	# WFE h3.block
	j 2b
	# read response and check it is zero
3:	lw t1, _SIO_FIFO_RD(t0)
	beqz t1, 4f
	# should have read zero here
	nop
4:
	popregs
	ret
