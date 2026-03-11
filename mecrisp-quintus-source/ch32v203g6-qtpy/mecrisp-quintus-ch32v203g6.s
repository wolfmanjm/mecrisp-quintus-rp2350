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
# Swiches for capabilities of this chip
# -----------------------------------------------------------------------------
.option arch, +zicsr

.option norelax
.option rvc
.equ compressed_isa, 1

# Note: After erasing is successful, word read - 0xe339e339, half word read - 0xe339, even address byte read - 0x39, odd address read 0xe3.

.equ erasedflashspecial, 1

.equ erasedbyte,     0x39
.equ erasedhalfword, 0xe339
.equ erasedword,     0xe339e339

.equ writtenhalfword, 0
.equ writtenword, 0

# -----------------------------------------------------------------------------
# Speicherkarte für Flash und RAM
# Memory map for Flash and RAM
# -----------------------------------------------------------------------------

# Konstanten für die Größe des Ram-Speichers

.equ RamAnfang,  0x20000000  # Start of RAM           Porting: Change this !
.equ RamEnde,    0x20002800  # End   of RAM.   10 kb. Porting: Change this !

# Konstanten für die Größe und Aufteilung des Flash-Speichers

.equ FlashAnfang, 0x00000000 # Start of Flash           Porting: Change this !
.equ FlashEnde,   0x00008000 # End   of Flash.   32 kb. Porting: Change this !

.equ FlashDictionaryAnfang, FlashAnfang + 0x5000 # 20 kb reserved for core.
.equ FlashDictionaryEnde,   FlashEnde

# define this to use 144MHz PLL, otherwise uses HSI at 8MHz
.equ USE_PLL_144MHZ, 1

# -----------------------------------------------------------------------------
# Core start
# -----------------------------------------------------------------------------

.text
    .align  4
  j Reset
# Exceptions and intterpts come here before the "Vector table of interrupt and
# exception" is proper initialized.
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
    .word     0x00000013    # nop
  j Reset
# -----------------------------------------------------------------------------
# Vector table
# -----------------------------------------------------------------------------
    .align  4
_vector_base: # Aligned on 4 Byte boundary.
    .option push
    .option norvc;
    .word   Reset
    .word   0
    .word   irq_collection             /* NMI */
    .word   irq_fault                  /* Hard Fault */
    .word   0
    .word   irq_collection             /* Ecall M Mode */
    .word   0
    .word   0
    .word   irq_collection             /* Ecall U Mode */
    .word   irq_collection             /* Break Point */
    .word   0
    .word   0
    .word   irq_systick                /* SysTick */
    .word   0
    .word   irq_software               /* SW */
    .word   0
    /* External Interrupts */
    .word   irq_collection             /* Window Watchdog */
    .word   irq_collection             /* PVD through EXTI Line detect */
    .word   irq_collection             /* TAMPER */
    .word   irq_collection             /* RTC */
    .word   irq_collection             /* Flash */
    .word   irq_collection             /* RCC */
    .word   irq_exti0                  /* EXTI Line 0 */
    .word   irq_exti1                  /* EXTI Line 1 */
    .word   irq_exti2                  /* EXTI Line 2 */
    .word   irq_exti3                  /* EXTI Line 3 */
    .word   irq_exti4                  /* EXTI Line 4 */
    .word   irq_collection             /* DMA1 Channel 1 */
    .word   irq_collection             /* DMA1 Channel 2 */
    .word   irq_collection             /* DMA1 Channel 3 */
    .word   irq_collection             /* DMA1 Channel 4 */
    .word   irq_collection             /* DMA1 Channel 5 */
    .word   irq_collection             /* DMA1 Channel 6 */
    .word   irq_collection             /* DMA1 Channel 7 */
    .word   irq_adc                    /* ADC1_2 */
    .word   irq_collection             /* USB HP and CAN1 TX */
    .word   irq_collection             /* USB LP and CAN1RX0 */
    .word   irq_collection             /* CAN1 RX1 */
    .word   irq_collection             /* CAN1 SCE */
    .word   irq_collection             /* EXTI Line 9..5 */
    .word   irq_collection             /* TIM1 Break */
    .word   irq_collection             /* TIM1 Update */
    .word   irq_collection             /* TIM1 Trigger and Commutation */
    .word   irq_collection             /* TIM1 Capture Compare */
    .word   irq_collection             /* TIM2 */
    .word   irq_collection             /* TIM3 */
    .word   irq_collection             /* TIM4 */
    .word   irq_collection             /* I2C1 Event */
    .word   irq_collection             /* I2C1 Error */
    .word   irq_collection             /* I2C2 Event */
    .word   irq_collection             /* I2C2 Error */
    .word   irq_collection             /* SPI1 */
    .word   irq_collection             /* SPI2 */
    .word   irq_collection             /* USART1 */
    .word   irq_collection             /* USART2 */
    .word   irq_collection             /* USART3 */
    .word   irq_collection             /* EXTI Line 15..10 */
    .word   irq_collection             /* RTC Alarm through EXTI Line */
    .word   irq_collection             /* USB Wake up from suspend */
    .word   irq_collection             /* USBHD Break */
    .word   irq_collection             /* USBHD Wake up from suspend */
    .word   irq_collection             /* UART4 */
    .word   irq_collection             /* DMA1 Channel8 */

    .option pop

# -----------------------------------------------------------------------------
# Include the Forth core of Mecrisp-Quintus
# -----------------------------------------------------------------------------

  .include "../common/forth-core.s"

# -----------------------------------------------------------------------------
Reset: # Forth begins here
# -----------------------------------------------------------------------------

# Microprocessor configuration registers (corecfgr)
# This register is mainly used to configure the microprocessor pipeline, instruction prediction and other related
# features, and generally does not need to be operated. The relevant MCU products are configured with default
# values in the startup file.

  li x15, 0x1f
  csrw 0xbc0, x15 # corecfgr

  # Enable nested and hardware stack
# PMTCFG:  0b00: No nesting, the number of preemption bits is 0.
# INESTEN: Interrupt nesting function enabled
# HWSTKEN: HPE function enabled;
  li x15, 0x3
  csrw 0x804, x15 # INTSYSCR ;

  la x15, _vector_base
  ori x15, x15, 3
  csrw mtvec, x15

  # Enable interrupt
  li x15, 0x88 + (3<<11)
  csrs mstatus, x15

#  SystemInit
   #   RCC->CTLR |= (uint32_t)0x00000001;
  li  x15,0x40021000
  lw  x14,0(x15)
  ori x14,x14,1
  sw  x14,0(x15)
   #   RCC->CFGR0 &= (uint32_t)0xF8FF0000;
  lw  x14,4(x15)
  li  x13,0xF8FF0000
  and x14,x14,x13
  sw  x14,4(x15)
   #   RCC->CTLR &= (uint32_t)0xFEF6FFFF;
  lw  x14,0(x15)
  li  x13,0xFEF6FFFF
  and x14,x14,x13
  sw  x14,0(x15)
   #   RCC->CTLR &= (uint32_t)0xFFFBFFFF;
  lw  x14,0(x15)
  li  x13,0xFFFBFFFF
  and x14,x14,x13
  sw  x14,0(x15)
   #   RCC->CFGR0 &= (uint32_t)0xFF80FFFF;
  lw  x14,4(x15)
  li  x13,0xFF80FFFF
  and x14,x14,x13
  sw  x14,4(x15)
   #   RCC->INTR = 0x009F0000;
  li  x14,0x009F0000
  sw  x14,8(x15)
   #   SetSysClock();
.if USE_PLL_144MHZ
  # Set extend register to not divide HSI by 2 for PLL
  li  x14,0x40023800
  lw  x13,0(x14)
  ori x13,x13,0x10
  sw x13,0(x14)

	# PLLCONFIG = RCC_PLLMul_18 18*8 = 144MHz
	lw  x14,4(x15)
  li  x13,0xFFC0FFFF
  and x14,x14,x13
  li  x13,0x003C0000
  or  x14,x14,x13
  sw  x14,4(x15)
	# enable PLL RCC->CTLR |= (1<<24);
  lw  x14,0(x15)
  li  x13,1<<24
  or  x14,x14,x13
  sw  x14,0(x15)
	# Wait for PLL ready
  li  x13,1<<25
1:
  lw  x14,0(x15)
  and x14,x13,x14
  beqz x14, 1b
  # Switch System Clock to PLL
  lw  x14,4(x15)
  li  x13,0xFFFFFFFC
  and x14,x14,x13
  ori x14,x14,0x02
  sw  x14,4(x15)
  # wait for it to be used
  li x13, 8
1:
  lw x14,4(x15)
  andi x14,x14,0x0C
  bne x14,x13,1b

.else
  nop # the HSI is used as System clock
.endif

  # Initialisations for terminal hardware, without stacks
  call uart_init

  # Catch the pointers for Flash dictionary
  .include "../common/catchflashpointers.s"

.if USE_PLL_144MHZ
  welcome " for RISC-V RV32IMC on CH32V203G6 @ 144MHz by Matthias Koch"
.else
  welcome " for RISC-V RV32IMC on CH32V203G6 by Matthias Koch"
.endif
  # Ready to fly !
  .include "../common/boot.s"
