.equ RESETS_BASE, 0x40020000
.equ RESETS_PLL_USB, 15
.equ RESETS_PLL_SYS, 14
.equ RESETS_PLLS, (1<<RESETS_PLL_USB) | (1<<RESETS_PLL_SYS)

.equ XOSC_BASE, 0x40048000
.equ XOSC_CTRL,    XOSC_BASE + 0x00 # Crystal Oscillator Control
.equ XOSC_STATUS,  XOSC_BASE + 0x04 # Crystal Oscillator Status
.equ XOSC_DORMANT, XOSC_BASE + 0x08 # Crystal Oscillator pause control
.equ XOSC_STARTUP, XOSC_BASE + 0x0C # Controls the startup delay
.equ XOSC_COUNT,   XOSC_BASE + 0x10 # A down counter running at the XOSC frequency which counts to zero and stops.

.equ TICKS_BASE, 0x40108000
.equ _TICKS_CTRL, 0x00
.equ _TICKS_CYCLES, 0x04
.equ _TICKS_COUNT, 0x08

.equ CLOCKS_BASE, 0x40010000
.equ _CLK_REF_CTRL, 0x30
.equ _CLK_REF_DIV, 0x34
.equ _CLK_REF_SELECTED, 0x38
.equ _CLK_SYS_CTRL, 0x3C
.equ _CLK_SYS_DIV, 0x40
.equ _CLK_SYS_SELECTED, 0x44
.equ _CLK_PERI_CTRL, 0x48
.equ _CLK_PERI_DIV, 0x4C
.equ _CLK_ADC_CTRL, 0x6c
.equ _CLK_ADC_DIV, 0x70



.equ _CLK_SYS_RESUS_CTRL, 0x84

.equ PLL_SYS_BASE, 0x40050000
.equ PLL_USB_BASE, 0x40058000
.equ PLL_CS, 0x0
.equ PLL_PWR, 0x4
.equ PLL_FBDIV_INT, 0x8
.equ PLL_PRIM, 0xc
.equ PLL_VCOPD, 5
.equ PLL_PD, 0
.equ PLL_POSTDIV1, 16
.equ PLL_POSTDIV2, 12
.equ PLL_CS_LOCK, 1 << 31
.equ PLL_START, (1<<PLL_VCOPD) | (1<<PLL_PD)
.equ PLL_SYS_DIV, (5<<PLL_POSTDIV1) | (2<<PLL_POSTDIV2)
.equ PLL_USB_DIV, (5<<PLL_POSTDIV1) | (4<<PLL_POSTDIV2)


setup_150mhz_clock:
	addi sp, sp, -48
  	sw ra, 0(sp)
  	sw x3, 4(sp)
	sw x4, 8(sp)
  	sw x5, 12(sp)
  	sw x6, 16(sp)
  	sw x7, 20(sp)
  	sw x8, 24(sp)
  	sw x9, 28(sp)
  	sw x10, 32(sp)
  	sw x11, 36(sp)
  	sw x12, 40(sp)
  	sw x13, 44(sp)

	# Disable Resus
	li t1, CLOCKS_BASE
	sw zero, _CLK_SYS_RESUS_CTRL(t1)

	# Configure XOSC to use 12 MHz crystal
	li t1, XOSC_CTRL      #  XOSC range 1-15MHz (Crystal Oscillator)
	li t2, 0x00000aa0
	sw t2, 0(t1)

	li t1, XOSC_STARTUP   # Startup Delay (default = 50,000 cycles aprox.)
	li t2, 0x0000011c
	sw t2, 0(t1)

	li t1, XOSC_CTRL | WRITE_SET   # Enable XOSC
	li t2, 0x00FAB000
	sw t2, 0(t1)

	li t1, XOSC_STATUS    # Wait for XOSC being stable
1:	lw t2, 0(t1)
	srli t2, t2, 31
	beqz t2, 1b

	# Before we touch PLLs, switch sys and ref cleanly away from their aux sources.
		# hw_clear_bits(&clocks_hw->clk[clk_sys].ctrl, CLOCKS_CLK_SYS_CTRL_SRC_BITS:1);
	li t1, CLOCKS_BASE | WRITE_CLR
	li t0, 1
	sw t0, _CLK_SYS_CTRL(t1)
		# while (clocks_hw->clk[clk_sys].selected != 0x1)
	li t1, CLOCKS_BASE
1:	lw t2, _CLK_SYS_SELECTED(t1)
	bne t0, t2, 1b
		# hw_clear_bits(&clocks_hw->clk[clk_ref].ctrl, CLOCKS_CLK_REF_CTRL_SRC_BITS:3);
	li t1, CLOCKS_BASE | WRITE_CLR
	li t0, 3
	sw t0, _CLK_REF_CTRL(t1)
		# while (clocks_hw->clk[clk_ref].selected != 0x1)
	li t1, CLOCKS_BASE
	li t0, 1
1:	lw t2, _CLK_REF_SELECTED(t1)
	bne t0, t2, 1b

	#	Reset PLLs
	li t1, RESETS_BASE | WRITE_SET
	li t0, RESETS_PLLS
	sw t0, 0(t1)
	li t1, RESETS_BASE | WRITE_CLR
	sw t0, 0(t1)
	li t1, RESETS_BASE
1:	lw t2, 8(t1) # RESETS_DONE
	and t2, t2, t0
	bne t2, t0, 1b

	# setup PLL for 150MHz from the XOSC

	# Don't divide the crystal frequency
	li t2, PLL_SYS_BASE
	li t3, PLL_USB_BASE
	li t0, 1
	sw t0, PLL_CS(t2)
	sw t0, PLL_CS(t3)

	# SYS: VCO = 12MHz * 125 = 1500MHz
	# USB: VCO = 12MHz *  80 =  960MHz
	li t0, 125
	sw t0, PLL_FBDIV_INT(t2)
	li t0, 80
	sw t0, PLL_FBDIV_INT(t3)

	# Start PLLs
	li t2, PLL_SYS_BASE | WRITE_CLR
	li t3, PLL_USB_BASE | WRITE_CLR
	li t0, PLL_START
	sw t0, PLL_PWR(t2)
	sw t0, PLL_PWR(t3)

	# Wait until both PLLs are locked
	li t2, PLL_SYS_BASE
	li t3, PLL_USB_BASE
	li t4, 0x80000000
1:	lw t0, PLL_CS(t2)
	lw t1, PLL_CS(t3)
	and t0, t0, t1
	and t0, t0, t4
	bne t0, t4, 1b

	# Set the PLL post dividers
	li t0, PLL_SYS_DIV
	li t1, PLL_USB_DIV
	sw t0, PLL_PRIM(t2)
	sw t1, PLL_PRIM(t3)
	li t2, PLL_SYS_BASE | WRITE_CLR
	li t3, PLL_USB_BASE | WRITE_CLR
	li t0, 8
	sw t0, PLL_PWR(t2)
	sw t0, PLL_PWR(t3)

	# setup clk_ref
	li t1, CLOCKS_BASE
	lw t2, _CLK_REF_CTRL(t1)
	# xori t2, t2, 0
	andi t2, t2, 0xE0
	li t1, CLOCKS_BASE | WRITE_XOR
	sw t2, _CLK_REF_CTRL(t1)

	li t1, CLOCKS_BASE
	lw t2, _CLK_REF_CTRL(t1)
	xori t2, t2, 2
	andi t2, t2, 0x03
	li t1, CLOCKS_BASE | WRITE_XOR
	sw t2, _CLK_REF_CTRL(t1)

	li t1, CLOCKS_BASE
1:	lw t2, _CLK_REF_SELECTED(t1)
	andi t2, t2, 1<<2
	beqz t2, 1b

	# Does nothing on ref clk
	# li t1, CLOCKS_BASE | WRITE_SET
	# li t2, 0x0800
	# sw t2, _CLK_REF_CTRL(t1)

	li t1, CLOCKS_BASE
	li t2, 1<<16
	sw t2, _CLK_REF_DIV(t1)


	# setup sys clk to 150MHz
	li t1, CLOCKS_BASE | WRITE_CLR
	li t2, 0x03
	sw t2, _CLK_SYS_CTRL(t1)
	li t1, CLOCKS_BASE
1:	lw t2, _CLK_SYS_SELECTED(t1)
	andi t2, t2, 1
	beqz t2, 1b

	li t1, CLOCKS_BASE
	lw t2, _CLK_SYS_CTRL(t1)
	# xori t2, t2, 0
	andi t2, t2, 0xE0
	li t1, CLOCKS_BASE | WRITE_XOR
	sw t2, _CLK_SYS_CTRL(t1)

	li t1, CLOCKS_BASE
	lw t2, _CLK_SYS_CTRL(t1)
	xori t2, t2, 1
	andi t2, t2, 0x03
	li t1, CLOCKS_BASE | WRITE_XOR
	sw t2, _CLK_SYS_CTRL(t1)

	li t1, CLOCKS_BASE
1:	lw t2, _CLK_SYS_SELECTED(t1)
	andi t2, t2, 1<<1
	beqz t2, 1b

	li t1, CLOCKS_BASE
	li t2, 1<<16
	sw t2, _CLK_SYS_DIV(t1)


	# Enable peripheral clock
	li t1, CLOCKS_BASE | WRITE_SET
	li t0, 0x800
	sw t0, _CLK_PERI_CTRL(t1)
	li t1, CLOCKS_BASE
	li t2, 1<<16
	sw t2, _CLK_PERI_DIV(t1)

	# Enable ADC clock
	li t1, CLOCKS_BASE | WRITE_SET
	li t0, 0x800
	sw t0, _CLK_ADC_CTRL(t1)
	li t1, CLOCKS_BASE
	li t2, 1<<16
	sw t2, _CLK_ADC_DIV(t1)

  	lw ra, 0(sp)
  	lw x3, 4(sp)
	lw x4, 8(sp)
  	lw x5, 12(sp)
  	lw x6, 16(sp)
  	lw x7, 20(sp)
  	lw x8, 24(sp)
  	lw x9, 28(sp)
  	lw x10, 32(sp)
  	lw x11, 36(sp)
  	lw x12, 40(sp)
  	lw x13, 44(sp)
  	addi sp, sp, 48
