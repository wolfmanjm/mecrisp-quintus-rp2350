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

# -----------------------------------------------------------------------------
  Definition Flag_visible, "roll" # ( xu xu-1 ... x0 u -- xu-1 ... x0 xu )
roll:
# -----------------------------------------------------------------------------
  # 2 ROLL is equivalent to ROT, 1 ROLL is equivalent to SWAP and 0 ROLL is a null operation.
  # TOS enthält das Element, welches am Ende nach oben rutschen soll.

  bne x8, zero, 1f # No moves ?
    drop
    ret

1:slli x8, x8, CELLSHIFT
  add x8, x8, x9
  lc x14, 0(x8) # Pick final TOS value temporarily into x14

  # One element is removed from the stack, let all other values fall down one place

  # (  5  4  3  2  1   TOS: 4)
  # (  5     3  2  1 )
  # (  5  3  2  1    )
  # ( 16 12  8  4  0


  # TOS contains number of moves, x8 number of bytes offset from stack pointer

  # Wo fange ich an ?
  # In der Lücke, die sich aufgetan hat. Lasse nachrutschen !
  # Also holen: Eine Stelle über der Lücke
  # Einfügen direkt in der Lücke.

  # Lückenadresse = psp + TOS*CELL

  # Lege von x8 - CELL an die Stelle x8.

2:lc x15, -CELL(x8)
  sc x15,     0(x8)
  addi x8, x8, -CELL
  bne x8, x9, 2b

  # Remove NOS element from stack
  addi x9, x9, CELL

  # Finished shifting of stack. Load result into TOS.
  mv x8, x14
  ret


# -----------------------------------------------------------------------------
  Definition Flag_visible, "-roll" # ( xu-1 ... x0 xu u -- xu xu-1 ... x0 u )
minusroll: # Kehrt die Wirkung von roll um.
# -----------------------------------------------------------------------------

  bne x8, zero, 1f # No moves ?
    drop
    ret

1:push x10

  # TOS contains number of moves.

  lc x10, 0(x9) # Das jetztige NOS soll später in die Lücke hinein, wird aber überschrieben.

  # (  5  4  3  2  1  X   TOS: 4)
  # (  5  4  4  3  2  1 )
  # (  5  X  4  3  2  1 )

  # Beginne direkt beim Stackpointer:
  mv x14, x9

2:# Mache nun die gewünschte Zahl von Schüben:
  lc x15, CELL(x14)
  sc x15,    0(x14)
  addi x14, x14, CELL
  addi x8, x8, -1
  bne x8, zero, 2b

  # Lege das NOS-Element in die Lücke
  sc x10, 0(x14)

  # Vergiss den Zähler in TOS
  drop

  pop x10
  ret
