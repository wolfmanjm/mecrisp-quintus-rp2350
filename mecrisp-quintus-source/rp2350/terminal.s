#
#    Mecrisp-Quintus - A native code Forth implementation for RISC-V
#    Copyright (C) 2018  Matthias Koch
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

.include "interrupts.s"
.include "cycles.s"
.include "../common/terminalhooks.s"
.include "multicore.s"

# -----------------------------------------------------------------------------
# Labels for a few hardware ports
# -----------------------------------------------------------------------------

# Memory map:

# 0x10000000                      XIP Base
# 0x20000000 - 0x2007FFFF: 512 kb SRAM
# 0x20080000 - 0x20081FFF:   8 kb SRAM, too

.equ RESETS_BASE, 0x40020000

.equ XOSC_BASE, 0x40048000
.equ XOSC_CTRL,    XOSC_BASE + 0x00 # Crystal Oscillator Control
.equ XOSC_STATUS,  XOSC_BASE + 0x04 # Crystal Oscillator Status
.equ XOSC_DORMANT, XOSC_BASE + 0x08 # Crystal Oscillator pause control
.equ XOSC_STARTUP, XOSC_BASE + 0x0C # Controls the startup delay
.equ XOSC_COUNT,   XOSC_BASE + 0x10 # A down counter running at the XOSC frequency which counts to zero and stops.

.equ CLOCKS_BASE, 0x40010000
.equ CLK_SYS_CTRL,   CLOCKS_BASE + 0x3C
.equ CLK_PERI_CTRL,  CLOCKS_BASE + 0x48

.equ IO_BANK0_BASE, 0x40028000
.equ GPIO_0_STATUS,  IO_BANK0_BASE + (8 *  0)
.equ GPIO_0_CTRL,    IO_BANK0_BASE + (8 *  0) + 4
.equ GPIO_1_STATUS,  IO_BANK0_BASE + (8 *  1)
.equ GPIO_1_CTRL,    IO_BANK0_BASE + (8 *  1) + 4
.equ GPIO_25_STATUS, IO_BANK0_BASE + (8 * 25)
.equ GPIO_25_CTRL,   IO_BANK0_BASE + (8 * 25) + 4

.equ PADS_BANK0_BASE, 0x40038000
.equ GPIO_0_PAD,     PADS_BANK0_BASE + 0x04
.equ GPIO_1_PAD,     PADS_BANK0_BASE + 0x08
.equ GPIO_25_PAD,    PADS_BANK0_BASE + 0x68

.equ SIO_BASE, 0xd0000000
.equ GPIO_IN,        SIO_BASE + 0x004  # Input value for GPIO pins
.equ GPIO_OUT,       SIO_BASE + 0x010  # GPIO output value
.equ GPIO_OE,        SIO_BASE + 0x030  # GPIO output enable

.equ UART0_BASE, 0x40070000
.equ UART0_DR   , UART0_BASE + 0x00 # Data Register, UARTDR
.equ UART0_RSR  , UART0_BASE + 0x04 # Receive Status Register/Error Clear Register, UARTRSR/UARTECR
.equ UART0_FR   , UART0_BASE + 0x18 # Flag Register, UARTFR
.equ UART0_ILPR , UART0_BASE + 0x20 # IrDA Low-Power Counter Register, UARTILPR
.equ UART0_IBRD , UART0_BASE + 0x24 # Integer Baud Rate Register, UARTIBRD
.equ UART0_FBRD , UART0_BASE + 0x28 # Fractional Baud Rate Register, UARTFBRD
.equ UART0_LCR_H, UART0_BASE + 0x2c # Line Control Register, UARTLCR_H
.equ UART0_CR   , UART0_BASE + 0x30 # Control Register, UARTCR
.equ UART0_IFLS , UART0_BASE + 0x34 # Interrupt FIFO Level Select Register, UARTIFLS
.equ UART0_IMSC , UART0_BASE + 0x38 # Interrupt Mask Set/Clear Register, UARTIMSC
.equ UART0_RIS  , UART0_BASE + 0x3c # Raw Interrupt Status Register, UARTRIS
.equ UART0_MIS  , UART0_BASE + 0x40 # Masked Interrupt Status Register, UARTMIS
.equ UART0_ICR  , UART0_BASE + 0x44 # Interrupt Clear Register, UARTICR
.equ UART0_DMACR, UART0_BASE + 0x48 # DMA Control Register, UARTDMACR

#  Define Atomic Register Access
#   See section 2.1.3 "Atomic Register Access" in RP2350 datasheet

.equ WRITE_NORMAL, (0x0000)   # Normal read write access
.equ WRITE_XOR   , (0x1000)   # Atomic XOR on write
.equ WRITE_SET   , (0x2000)   # Atomic bitmask set on write
.equ WRITE_CLR   , (0x3000)   # Atomic bitmask clear on write

# set to 1 for 150MHz clocks, otherwise uses the 12MHz xtal clock
.equ FULLSPEED, 1
# -----------------------------------------------------------------------------
uart_init:
# -----------------------------------------------------------------------------

  # Start cycle counter
  csrrwi zero, 0x320, 4  # MCOUNTINHIBIT: Keep minstret(h) stopped, but run mcycle(h).

  # Remove reset of all subsystems
  li x15, RESETS_BASE
  sw zero, 0(x15)

.if FULLSPEED
	.include "clocks.s"
.else
  # Configure XOSC to use 12 MHz crystal

  li x15, XOSC_CTRL      #  XOSC range 1-15MHz (Crystal Oscillator)
  li x14, 0x00000aa0
  sw x14, 0(x15)

  li x15, XOSC_STARTUP   # Startup Delay (default = 50,000 cycles aprox.)
  li x14, 0x000000c4
  sw x14, 0(x15)

  li x15, XOSC_CTRL | WRITE_SET   # Enable XOSC
  li x14, 0x00FAB000
  sw x14, 0(x15)

  li x15, XOSC_STATUS    # Wait for XOSC being stable
1:lw x14, 0(x15)
  srli x14, x14, 31
  beq x14, zero, 1b

  # Select main clock
  li x15, CLK_SYS_CTRL
  li x14, (3 << 5)
  sw x14, 0(x15)

  # Enable peripheral clock
  li x15, CLK_PERI_CTRL
  li x14, 0x800 | (4 << 5)   # Enabled, XOSC as source
  sw x14, 0(x15)
.endif


  # Set GPIO[0,1] function to UART: Function 2 UART
  li x15, GPIO_0_CTRL   # TX
  li x14, 2
  sw x14, 0(x15)

  li x15, GPIO_1_CTRL   # RX
  li x14, 2
  sw x14, 0(x15)

  # Remove pad isolation control bits for the UART pins, and enable input on the RX wire
  li x15, GPIO_0_PAD   # TX
  li x14, 0
  sw x14, 0(x15)

  li x15, GPIO_1_PAD   # RX
  li x14, (1 << 6)
  sw x14, 0(x15)

  # Configure UART0

.if FULLSPEED
	# 115200 baud 81.38 with sysclk @ 150MHz
	.equ UART_IBAUD, 81
	.equ UART_FBAUD, 24
.else
  	#   Baud: For a baud rate of 115200 with UARTCLK = 12MHz then:
  	#   Baud Rate Divisor = 12000000/(16 * 115200) ~= 6.5104
	.equ UART_IBAUD, 6
	.equ UART_FBAUD, 33
.endif
  li x15, UART0_IBRD
  li x14, UART_IBAUD
  sw x14, 0(x15)

  li x15, UART0_FBRD
  li x14, UART_FBAUD
  sw x14, 0(x15)

  li x15, UART0_LCR_H
  li x14, (3 << 5) | (1 << 4) # 8N1, FIFOs enabled
  sw x14, 0(x15)

  li x15, UART0_CR
  li x14, (1 << 9) | (1 << 8) | (1 << 0) # Receive enable, transmit enable, UART enable
  sw x14, 0(x15)

  # Set interrupt handler

  la x15, irq_collection
  csrrw x0, mtvec, x15

  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-emit"
serial_emit: # ( c -- ) Emit one character
# -----------------------------------------------------------------------------
  push x1

1:call serial_qemit
  popda x15
  beq x15, zero, 1b

  li x14, UART0_DR
  sb x8, 0(x14)
  drop

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-key"
serial_key: # ( -- c ) Receive one character
# -----------------------------------------------------------------------------
  push x1

1:call serial_qkey
  popda x15
  beq x15, zero, 1b

  pushdatos
  li x14, UART0_DR
  lbu x8, 0(x14)

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-emit?"
serial_qemit:  # ( -- ? ) Ready to send a character ?
# -----------------------------------------------------------------------------
  push x1
  call pause

  pushdatos
  li x8, UART0_FR
  lw x8, 0(x8)
  andi x8, x8, 0x20  # UARTFR_TX_FIFO_FULL, Bit 5

  sltiu x8, x8, 1 # 0=
  sub x8, zero, x8

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-key?"
serial_qkey:  # ( -- ? ) Is there a key press ?
# -----------------------------------------------------------------------------
  push x1
  call pause

  pushdatos
  li x8, UART0_FR
  lw x8, 0(x8)
  andi x8, x8, 0x10  # UARTFR_RX_FIFO_EMPTY, Bit 4

  sltiu x8, x8, 1 # 0=
  sub x8, zero, x8

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "reset"
# -----------------------------------------------------------------------------

  li x15, 0x400d8000 # Watchdog CTRL
  li x14, 0x80000000 # Trigger
  sw x14, 0(x15)

  ret # Just for the emulator, the real chip resets now.
