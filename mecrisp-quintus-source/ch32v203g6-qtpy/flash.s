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

# addresses, constant and mask
.equ PERIPH_BASE, (0x40000000) # /* Peripheral base address in the alias region */
.equ AHBPERIPH_BASE, (PERIPH_BASE + 0x20000)
.equ FLASH_R_BASE, (AHBPERIPH_BASE + 0x2000)
# FLASH Registers
.equ OFFSET_ACTLR,    (0 * 4)
.equ OFFSET_KEYR,     (1 * 4)
.equ OFFSET_OBKEYR,   (2 * 4)
.equ OFFSET_STATR,    (3 * 4)
.equ OFFSET_CTLR,     (4 * 4)
.equ OFFSET_ADDR,     (5 * 4)
.equ OFFSET_RESERVED, (6 * 4)
.equ OFFSET_OBR,      (7 * 4)
.equ OFFSET_WPR,      (8 * 4)
.equ OFFSET_MODEKEYR, (9 * 4)

.equ CR_PG_Set, (0x00000001)
.equ CR_PG_Reset, (0xFFFFFFFE)
.equ CR_LOCK_Set, (0x00000080)
.equ CR_PER_Set, (0x00000002)
.equ CR_MER_Set, (0x00000004)
.equ CR_STRT_Set, (0x00000040)
.equ CR_MER_Reset, (0xFFFFFFFB)
.equ FLASH_FLAG_BSY, (0x00000001) # FLASH Busy flag
.equ FLASH_FLAG_BANK1_BSY, FLASH_FLAG_BSY # FLASH BANK1 Busy flag
.equ FLASH_FLAG_WRPRTERR, (0x00000010) # FLASH Write protected error flag
.equ FLASH_FLAG_BANK1_WRPRTERR, FLASH_FLAG_WRPRTERR  # FLASH BANK1 Write protected error flag
# FLASH Keys
.equ RDP_Key,                    (0x00A5)
.equ FLASH_KEY1,                 (0x45670123)
.equ FLASH_KEY2,                 (0xCDEF89AB)

# hepers
flash_lockbank1:
flash_lock:
  li x15, FLASH_R_BASE
  lw x14, OFFSET_CTLR(x15)
  ori x14, x14, CR_LOCK_Set
  sw x14, OFFSET_CTLR(x15)
  ret

flash_unlock:
flash_unlockbank1:
  li x15, FLASH_R_BASE
  li x14, FLASH_KEY1
  sw x14, OFFSET_KEYR(x15)
  li x14, FLASH_KEY2
  sw x14, OFFSET_KEYR(x15)
  ret

flash_waitforlastoperation:
  li x15, FLASH_R_BASE
1:
  lw x14, OFFSET_STATR(x15)
  andi x14, x14, FLASH_FLAG_BANK1_BSY
  bne x14, zero, 1b # until busy
  lw x14, OFFSET_STATR(x15)
  andi x14, x14, FLASH_FLAG_BANK1_WRPRTERR
  beq x14, zero, 1f
  writeln "Erasing flash error !"
1:
  ret

flash_eraseallpages:
flash_eraseallbank1pages:
  push_x1_x10_x11
  call flash_unlock
  li x10, FLASH_R_BASE
  call flash_waitforlastoperation
  lw x11, OFFSET_CTLR(x10)
  li x14, CR_MER_Set
  li x15, CR_STRT_Set
  or x11, x11, x14
  sw x11, OFFSET_CTLR(x10)
  lw x11, OFFSET_CTLR(x10)
  or x11, x11, x15
  sw x11, OFFSET_CTLR(x10)
  call flash_waitforlastoperation
  lw x11, OFFSET_CTLR(x10)
  li x14, CR_MER_Reset
  and x11, x11, x14
  sw x11, OFFSET_CTLR(x10)
  call flash_lock
  pop_x1_x10_x11
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "hflash!" # ( x Addr -- )
  # Schreibt an eine gerade Adresse in den Flash.
# -----------------------------------------------------------------------------
hflashstore:
  push_x1_x10_x11

  # Ist die gewünschte Stelle im Flash-Dictionary ? / Is the desired location in the flash dictionary ?
  dup
  call addrinflash
  popda x15
  beq x15, zero, 3f

  # Außerhalb des Forth-Kerns ? / Outside the Forth core ?
  laf x15, FlashDictionaryAnfang # FlashDictionaryBeginning
  bltu x8, x15, 3f

  popda x10 # Adresse
  popda x11 # Inhalt. / Contents.

  # Prüfe die Adresse: Sie muss gerade sein: / Check the address: it must be straight:
  andi x15, x10, 1
  bne x15, zero, 3f

  # Ist an der gewünschten Stelle $FFFF im Speicher ? / Is $FFFF in memory at the desired location ?
  lhu x15, 0(x10)
  li x14, erasedhalfword
  bne x15, x14, 3f

  # Prüfe Inhalt. Schreibe nur, wenn es NICHT -1 ist. / Check content. Write only if it is NOT -1.
  li x15, erasedhalfword
  beq x11, x15, 2f

  # Alles paletti. Schreibe tatsächlich ! / Everything alright. Actually write!
  call flash_unlock
  call flash_waitforlastoperation

  # Flash-Speicher ist gespiegelt, die wirkliche Adresse liegt weiter hinten !
  # Flash memory is mirrored, use true address later for write
  li x14, 0x08000000
  add x10, x10, x14

  # Write to Flash !
  li x15, FLASH_R_BASE
  lw x14, OFFSET_CTLR(x15)
  ori x14, x14, CR_PG_Set
  sw x14, OFFSET_CTLR(x15)

  sh x11, 0(x10)

  lw x14, OFFSET_CTLR(x15)
  andi x14, x14, CR_PG_Reset
  sw x14, OFFSET_CTLR(x15)

  # Wait for Flash BUSY Flag to be cleared
  call flash_waitforlastoperation

  # Lock Flash after finishing this
  call flash_lock

2:pop_x1_x10_x11
  ret

3:writeln "Wrong address or data for writing flash !"
  j quit

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flash!" # ( x Addr -- )
# -----------------------------------------------------------------------------
flashstore:
  push x1

  over
  li x15, 0xFFFF
  and x8, x8, x15
  over
  call hflashstore

  addi x8, x8, 2
  lw x15, 0(x9)
  srli x15, x15, 16
  sw x15, 0(x9)
  call hflashstore

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flashpageerase" # ( Addr -- )
  # Löscht einen 4kb großen Flashblock.  Deletes one 4kb Flash page.
flashpageerase:
# -----------------------------------------------------------------------------
  push x1

  # Ist die gewünschte Stelle im Flash-Dictionary ?
  dup
  call addrinflash
  popda x15
  beq x15, zero, 2f

  # Außerhalb des Forth-Kerns ?
  laf x15, FlashDictionaryAnfang
  bltu x8, x15, 2f

  call flash_waitforlastoperation
  call flash_unlock

  # Enable erase
  li x15, FLASH_R_BASE
  lw x14, OFFSET_CTLR(x15)
  ori x14, x14, CR_PER_Set
  sw x14, OFFSET_CTLR(x15)

  # Flash-Speicher ist gespiegelt, die wirkliche Adresse liegt weiter hinten !
  # Flash memory is mirrored, use true address later for write
  li x14, 0x08000000
  add x8, x8, x14

  # Set page to erase
  sw x8, OFFSET_ADDR(x15)
  drop

  # Start erasing
  lw x14, OFFSET_CTLR(x15)
  ori x14, x14, CR_STRT_Set
  sw x14, OFFSET_CTLR(x15)

    # Wait for Flash BUSY Flag to be cleared
  call flash_waitforlastoperation

  # Lock Flash after finishing this
  call flash_lock

  pop x1
  ret

2:writeln "Wrong address for erasing flash !"
  j quit

# -----------------------------------------------------------------------------
  Definition Flag_visible, "eraseflash" # ( -- )
  # Löscht den gesamten Inhalt des Flashdictionaries.
# -----------------------------------------------------------------------------
        li x10, FlashDictionaryAnfang

eraseflash_intern:
        li x11, FlashDictionaryEnde
        li x12, erasedword

1:      lw x13, 0(x10)
        beq x13, x12, 2f
          pushda x10
            dup
            write "Erase block at  "
            call hexdot
            writeln " from Flash"
          call flashpageerase
2:      addi x10, x10, 4
        bne x10, x11, 1b
  writeln "Finished. Reset !"

  j Reset

# -----------------------------------------------------------------------------
  Definition Flag_visible, "eraseflashfrom" # ( Addr -- )
  # Beginnt an der angegebenen Adresse mit dem Löschen des Dictionaries.
# -----------------------------------------------------------------------------
  popda x10
  j eraseflash_intern
