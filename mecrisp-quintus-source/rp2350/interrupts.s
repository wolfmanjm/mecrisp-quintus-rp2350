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

# Interrupt handling and CSR register access

  .include "../common/interrupt-common.s"

.equ RVCSR_MEIEA_OFFSET, 0x00000be0
.equ RVCSR_MEIFA_OFFSET, 0x00000be2
.equ RVCSR_MIE_MEIE_BITS, 0x00000800
.equ RVCSR_MEINEXT_OFFSET, 0x00000be4

# -----------------------------------------------------------------------------
  Definition Flag_visible, "enable-irq" # enable the IRQ
enable_irq:
# -----------------------------------------------------------------------------
	mv x14, x8
	drop
	# enable global interrupt
    li x15, RVCSR_MIE_MEIE_BITS
    csrw mie, x15
    # enable specific interrupt
    srli x15, x14, 5 				# n
    slli x15, x15, 1				# 2*n
    andi x16, x14, 31 				# mask
    bset x16, zero, x16 			# bitset
	slli x17, x16, 16				# upper 16 bits are bit to set (mask),
	or x17, x17, x15 				# lower 5 bits are the window (n)
	csrc RVCSR_MEIFA_OFFSET, x17
	csrs RVCSR_MEIEA_OFFSET, x17 	# enable
	srli x17, x16, 16
	addi x15, x15, 1
	slli x17, x17, 16				# upper 16 bits are bit to set (mask),
	or x17, x17, x15 				# lower 5 bits are the window (n)
	csrc RVCSR_MEIFA_OFFSET, x17
	csrs RVCSR_MEIEA_OFFSET, x17
	ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "disable-irq" # disable the IRQ
disable_irq:
# -----------------------------------------------------------------------------
	mv x14, x8
	drop
    srli x15, x14, 5 				# n
    slli x15, x15, 1				# 2*n
    andi x16, x14, 31 				# mask
    bset x16, zero, x16 			# bitset
	slli x17, x16, 16				# upper 16 bits are bit to set (mask),
	or x17, x17, x15 				# lower 5 bits are the window (n)
	csrc RVCSR_MEIEA_OFFSET, x17 	# disable
	srli x17, x16, 16
	addi x15, x15, 1
	slli x17, x17, 16				# upper 16 bits are bit to set (mask),
	or x17, x17, x15 				# lower 5 bits are the window (n)
 	csrc RVCSR_MEIEA_OFFSET, x17
	ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mepc!" # Where did it occour ?
mepc_store:
# -----------------------------------------------------------------------------
  csrrw x0, mepc, x8
  drop
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mepc@" # Where did it occour ?
mepc_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mepc, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mtvec!" # Where did it occour ?
mtvec_store:
# -----------------------------------------------------------------------------
  csrrw x0, mtvec, x8
  drop
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mtvec@" # Where did it occour ?
mtvec_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mtvec, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mcause@" # Which interrupt ?
mcause_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mcause, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "meinext@" # Which external interrupt ?
meinext_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrr x8, RVCSR_MEINEXT_OFFSET
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "fault" # Message for unhandled exceptions
fault:
# -----------------------------------------------------------------------------
  push x1

  write "Unhandled Exception"
  call trap_signature

  # Advance the location we are returning to in order to skip the faulty instruction
  csrrs x15, mepc, zero
  lhu x14, 0(x15)     # Fetch the opcode which caused this exception

  andi x14, x15,  3   # Compressed opcodes end with %00, %01 or %10. Normal 4 byte opcodes end with %11.
  addi x14, x14, -3   # Gives zero for long opcodes only

  addi x15, x15,  2   # Skip 2 bytes for a compressed opcode
  bne  x14, zero, 1f
  addi x15, x15,  2 # Skip 4 bytes in total for a long opcode

1:csrrw x0, mepc, x15 # Set return address.

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "unhandled" # Message for wild interrupts
unhandled:                             #   and handler for unused interrupts
# -----------------------------------------------------------------------------
  csrrs x15, mcause, zero
  blt zero, x15, fault # Exception (sign bit set) or interrupt?

  push x1

  write "Unhandled Interrupt"
  call trap_signature

  pop x1
  ret

# -----------------------------------------------------------------------------
trap_signature:
# -----------------------------------------------------------------------------
  push x1

  write " mcause: "
  call mcause_fetch
  call hexdot

  write "mepc: "
  call mepc_fetch
  call hexdot

  # FOR DEBUG
  # write "meinext: "
  # call meinext_fetch
  # call hexdot

  writeln "!"

  pop x1
  ret

# -----------------------------------------------------------------------------
  .include "../common/irq-handler.s"
# -----------------------------------------------------------------------------

# Collection vector:
initinterrupt          collection, irq_collection, unhandled
#                      Forth-Name  Assembler-Name  Default handler
