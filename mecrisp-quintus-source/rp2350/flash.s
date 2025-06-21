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

# Cannot write to memory mapped SPI flash in XIP mode,
# but to precompile in emulator:

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flash!"
flashstore: # ( x addr -- )
# -----------------------------------------------------------------------------
  j store

# -----------------------------------------------------------------------------
  Definition Flag_visible, "hflash!"
hflashstore: # ( x addr -- )
# -----------------------------------------------------------------------------
  j hstore


#------------------------------------------------------------------------------
  Definition Flag_foldable_1, "image>spi-offset" # ( u -- addr )
image2spioffset:                                 # Calculate start address for image in SPI flash
#------------------------------------------------------------------------------
  # Every image is 256 kb in size, and contains everything.
  slli x8, x8, 18  # Just multiply with image size
  ret

#------------------------------------------------------------------------------
  Definition Flag_visible, "erase#" # ( u -- )
eraseimage:                         # Erase an image from the SPI flash
#------------------------------------------------------------------------------
  push x1
  call image2spioffset   # Calculate offset into flash memory from which to erase
  pushdaconst 0x00040000 # Size to erase: 256 kb
  call erase_range
  pop x1
  ret

#------------------------------------------------------------------------------
  Definition Flag_visible, "save#" # ( u -- )
save:                              # Save current dictionary contents into SPI flash image
#------------------------------------------------------------------------------
  push x1

  dup
  call eraseimage

  call image2spioffset       # Calculate offset into flash memory to which we wish to write
  pushdaconst 0x20000000     # Take data from the "compiletoflash" area in RAM
  pushdaconst 0x00040000     # Size to write: 256 kb
  call program_range

  pop x1
  ret

#------------------------------------------------------------------------------
  Definition Flag_visible, "load#" # ( u -- )
                                   # Load dictionary image from SPI flash
#------------------------------------------------------------------------------

  # No need to push x1, as this never returns.

  call image2spioffset
  li x14, 0x10000000
  add x8, x8, x14            # Source address
  pushdaconst 0x20000000     # Destination address
  pushdaconst 0x00040000     # 256 kb
  call move

  j Reset

#------------------------------------------------------------------------------
  Definition Flag_visible, "save" # ( -- )
                                  # Save current dictionary contents in image 0 which is loaded automatically on boot
#------------------------------------------------------------------------------
  pushdaconst 0
  j save

#------------------------------------------------------------------------------
  Definition Flag_visible, "new" # ( -- )
                                 # Clear the dictionary and restart
#------------------------------------------------------------------------------
  # No need to push x1, as this never returns.

  pushdaconst FlashDictionaryAnfang
  pushdaconst FlashDictionaryEnde - FlashDictionaryAnfang
  pushdaconst 0xFF
  call fill

  j Reset

#------------------------------------------------------------------------------
   Definition Flag_visible, "restart" # ( -- )
#------------------------------------------------------------------------------
  j Reset


# -----------------------------------------------------------------------------
#   Macros to save most registers as C and Quintus have different calling conventions
# -----------------------------------------------------------------------------

.macro pushregs
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
.endm

.macro popregs
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
.endm

# -----------------------------------------------------------------------------
  Definition Flag_visible, "erase-range"
erase_range: # ( addr length -- )
# -----------------------------------------------------------------------------

# Erase count bytes, starting at addr (offset from start of flash). Optionally, pass a block erase command e.g. D8h block
# erase, and the size of the block erased by this command — this function will use the larger block erase where possible,
# for much higher erase speed. addr must be aligned to a 4096-byte sector, and count must be a multiple of 4096 bytes.

  # Deactivate interrupts, because C code might "disconnect" the data stack pointer.
  csrrci zero, mstatus, 8 # Clear Machine Interrupt Enable Bit

  pushregs # Save x1, x3 to x13. Switch register set from "Forth-ABI" to "C-ABI"

  lw x10, 0(x9)  # NOS --> a0: address, aligned to 4096
  mv x11, x8     # TOS --> a1: length,  multiples of 4096

  call flash_erase_range

  popregs
  drop
  drop
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "program-range"
program_range: # ( addr source length -- )
# -----------------------------------------------------------------------------

# Program data to a range of flash storage addresses starting at addr (offset from the start of flash) and count bytes in
# size. addr must be aligned to a 256-byte boundary, and count must be a multiple of 256.

  # Deactivate interrupts, because C code might "disconnect" the data stack pointer.
  csrrci zero, mstatus, 8 # Clear Machine Interrupt Enable Bit

  pushregs # Save x1, x3 to x13. Switch register set from "Forth-ABI" to "C-ABI"

  lw x10, 4(x9)  # 3OS --> a0: address, aligned to 256
  lw x11, 0(x9)  # NOS --> a1: source address for the data that will be written
  mv x12, x8     # TOS --> a2: length,  multiples of 256

  call flash_program_range

  popregs
  drop
  drop
  drop
  ret



# -----------------------------------------------------------------------------
#  Routines to call into the bootrom for actually writing & erasing flash memory
# -----------------------------------------------------------------------------

# code to flash to the qspi chip using calls into ROM

.equ FLASH_PAGE_SIZE, 1 << 8    # 256
.equ FLASH_SECTOR_SIZE, 1 << 12 # 4096
.equ FLASH_BLOCK_SIZE, 1 << 16
.equ FLASH_BLOCK_ERASE_CMD, 0xd8

.equ ROM_DATA_SOFTWARE_GIT_REVISION,    ('G' | ('R'<<8))
.equ ROM_FUNC_FLASH_ENTER_CMD_XIP,      ('C' | ('X'<<8))
.equ ROM_FUNC_FLASH_EXIT_XIP,           ('E' | ('X'<<8))
.equ ROM_FUNC_FLASH_FLUSH_CACHE,        ('F' | ('C'<<8))
.equ ROM_FUNC_CONNECT_INTERNAL_FLASH,   ('I' | ('F'<<8))
.equ ROM_FUNC_FLASH_RANGE_ERASE,        ('R' | ('E'<<8))
.equ ROM_FUNC_FLASH_RANGE_PROGRAM,      ('R' | ('P'<<8))

.equ BOOTROM_WELL_KNOWN_PTR_SIZE, 2
.equ BOOTROM_ENTRY_OFFSET, 0x7dfc
.equ BOOTROM_TABLE_LOOKUP_ENTRY_OFFSET, (BOOTROM_ENTRY_OFFSET - BOOTROM_WELL_KNOWN_PTR_SIZE)
#define BOOTROM_TABLE_LOOKUP_OFFSET     (BOOTROM_ENTRY_OFFSET - BOOTROM_WELL_KNOWN_PTR_SIZE*2)
.equ RT_FLAG_FUNC_RISCV, 0x0001

.equ QMI_BASE, 0x400d0000
  .equ _M1_TIMING, 0x00000020
  .equ _M1_RFMT, 0x00000024
  .equ _M1_RCMD, 0x00000028

# a0 is rom code to lookup, returns address of rom function
rom_func_lookup:
	# rom_size_is_64k()  return *(uint16_t*)0x14 >= 0x8000; }
	li t0, 0x14
	lh t1, 0(t0)
	li t0, 0x8000
	mv t2, zero			# romoffsetadjust
	blt t1, t0, 1f
	li t2, 32 * 1024
1:	# get rom table lookup fnc and call it
	li t0, BOOTROM_TABLE_LOOKUP_ENTRY_OFFSET
	add t0, t0, t2
	lh t0, 0(t0)
	li a1, RT_FLAG_FUNC_RISCV
	addi sp, sp, -4
  	sw ra, 0(sp)
	jalr t0 	# calls rom table lookup funcion
  	lw ra, 0(sp)
  	addi sp, sp, 4
	# a0 has rom func address
2:	beqz a0, 2b		# will loop here if there was an error getting the function address
	ret

# a0: flash_offs, a1: count returns a0: 0 if ok
# flash_offs & (FLASH_SECTOR_SIZE - 1) must be zero
# count & (FLASH_SECTOR_SIZE - 1) must be zero
.globl flash_erase_range
flash_erase_range:
	li t0, FLASH_SECTOR_SIZE - 1
	and t1, a0, t0
	bnez t1, 1f
	and t1, a1, t0
	bnez t1, 1f
	j 2f
1:	li a0, 1
	ret

2:
#    flash_init_boot2_copyout(); 	// not required as we are running from RAM FIXME if not
#    xip_cache_clean_all(); 		// also not required if running from RAM

	# save qmi and ra on stack
	addi sp, sp, -24
	li t0, QMI_BASE
	lw t1, _M1_TIMING(t0)
	sw t1, 0(sp)
	lw t1, _M1_RCMD(t0)
	sw t1, 4(sp)
	lw t1, _M1_RFMT(t0)
	sw t1, 8(sp)
	sw s1, 12(sp)
	sw s2, 16(sp)
	sw ra, 20(sp)

	# save parameters
	mv s1, a0
	mv s2, a1

	# connect_internal_flash_func()
	li a0, ROM_FUNC_CONNECT_INTERNAL_FLASH
	call rom_func_lookup
	jalr a0 	# calls rom table lookup funcion
	# flash_exit_xip_func();
	li a0, ROM_FUNC_FLASH_EXIT_XIP
	call rom_func_lookup
	jalr a0

    # flash_range_erase_func(flash_offs, count, FLASH_BLOCK_SIZE, FLASH_BLOCK_ERASE_CMD);
	li a0, ROM_FUNC_FLASH_RANGE_ERASE
	call rom_func_lookup
	mv t0, a0
	mv a0, s1
	mv a1, s2
	li a2, FLASH_BLOCK_SIZE
	li a3, FLASH_BLOCK_ERASE_CMD
	jalr t0

    # flash_flush_cache_func(); // Note this is needed to remove CSn IO force as well as cache flushing
    li a0, ROM_FUNC_FLASH_FLUSH_CACHE
    call rom_func_lookup
    jalr a0

    # flash_enable_xip_via_boot2(); // should be done to turn xip back on if needed


	# restore qmi from stack (FIXME there is some extra checking that needs doing if running from flash)
	li t0, QMI_BASE
	lw t1, 0(sp)
	sw t1, _M1_TIMING(t0)
	lw t1, 4(sp)
	sw t1, _M1_RCMD(t0)
	lw t1, 8(sp)
	sw t1, _M1_RFMT(t0)
	lw s1, 12(sp)
	lw s2, 16(sp)
	lw ra, 20(sp)
	addi sp, sp, 24
	mv a0, zero

	ret



# a0: flash_offs, a1: data, a2: count
# flash_offs & (FLASH_PAGE_SIZE - 1) must be zero
# count & (FLASH_PAGE_SIZE - 1) must be zero
.globl flash_program_range
flash_program_range:
	li t0, FLASH_PAGE_SIZE - 1
	and t1, a0, t0
	bnez t1, 1f
	and t1, a2, t0
	bnez t1, 1f
	j 2f
1:	li a0, 1
	ret
2:
	# save qmi and ra on stack
	addi sp, sp, -28
	li t0, QMI_BASE
	lw t1, _M1_TIMING(t0)
	sw t1, 0(sp)
	lw t1, _M1_RCMD(t0)
	sw t1, 4(sp)
	lw t1, _M1_RFMT(t0)
	sw t1, 8(sp)
	sw s1, 12(sp)
	sw s2, 16(sp)
	sw s3, 20(sp)
	sw ra, 24(sp)

	# save parameters
	mv s1, a0
	mv s2, a1
	mv s3, a2

	# connect_internal_flash_func()
	li a0, ROM_FUNC_CONNECT_INTERNAL_FLASH
	call rom_func_lookup
	jalr a0 	# calls rom table lookup funcion
	# flash_exit_xip_func();
	li a0, ROM_FUNC_FLASH_EXIT_XIP
	call rom_func_lookup
	jalr a0

    # flash_range_program_func(flash_offs, data, count);
	li a0, ROM_FUNC_FLASH_RANGE_PROGRAM
	call rom_func_lookup
	mv t0, a0
	mv a0, s1
	mv a1, s2
	mv a2, s3
	jalr t0

    # flash_flush_cache_func(); // Note this is needed to remove CSn IO force as well as cache flushing
    li a0, ROM_FUNC_FLASH_FLUSH_CACHE
    call rom_func_lookup
    jalr a0

    # flash_enable_xip_via_boot2(); // should be done to turn xip back on if needed

	# restore qmi from stack (FIXME there is some extra checking that needs doing if running from flash)
	li t0, QMI_BASE
	lw t1, 0(sp)
	sw t1, _M1_TIMING(t0)
	lw t1, 4(sp)
	sw t1, _M1_RCMD(t0)
	lw t1, 8(sp)
	sw t1, _M1_RFMT(t0)
	lw s1, 12(sp)
	lw s2, 16(sp)
	lw s3, 20(sp)
	lw ra, 24(sp)
	addi sp, sp, 28
	mv a0, zero

	ret

