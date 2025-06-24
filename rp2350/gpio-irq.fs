\ Test pin irq

\ GPIO events must be set to one or all of these
1 0 lshift constant b_INTR_LEVEL_LOW
1 1 lshift constant b_INTR_LEVEL_HIGH
1 2 lshift constant b_INTR_EDGE_LOW
1 3 lshift constant b_INTR_EDGE_HIGH

$40028000 constant IO_BANK0_BASE
IO_BANK0_BASE $00000230 + constant _INTR0
IO_BANK0_BASE $00000248 + constant _PROC0_INTE0
IO_BANK0_BASE $00000278 + constant _PROC0_INTS0
IO_BANK0_BASE 14 8 * + 4 + constant GPIO_14_CTRL

21 constant IO_IRQ_BANK0

$4003803C constant PADS_BANK0_GPIO14 \ Pad control register

\ clears then sets a range of bits in addr
\ uses atomic sets and clear in the rp2350
: clr-set-bits! ( value mask pos addr -- )
    >r tuck                     \ -- value pos mask pos
    lshift r@ $3000 or !        \ clear mask first -- value pos
    lshift r> $2000 or !        \ set the value bits
;

\ acks the specified event for the pin#
: gpio-ack-irq ( eventmask pin# -- )
    dup 3 rshift 2 lshift _INTR0 +  \ register offset for this gpio -- eventmask pin# regoff
    swap %0111 and 2 lshift         \ (gpio mod 8) * 4 -- eventmask regoff shift
    rot swap lshift                 \ shift event into correct position
    swap !                          \ set event bits
;

\ enable interrupts on pin#
: gpio-irq-enable ( eventmask pin# -- )
    \ first ack any outstanding IRQ for the given events
    2dup gpio-ack-irq

    dup 3 rshift 2 lshift _PROC0_INTE0 +    \ register offset for this gpio -- eventmask pin# regoff
    swap %0111 and 2 lshift                 \ (gpio mod 8) * 4 -- eventmask regoff shift
    swap                                    \ -- eventmask shift register
    %1111 -rot                              \ -- eventmask %1111 shift register
    clr-set-bits!                           \ clear the bit range then set it to eventmask
;

\ Get IRQ status for specified pin#
: gpio-irq-status ( pin# -- eventmask )
    dup 3 rshift 2 lshift _PROC0_INTS0 +    \ register offset for this pin# -- pin# regoff
    swap %0111 and 2 lshift                 \ (gpio mod 8) * 4 -- regoff shift
    swap @ swap rshift %01111 and           \ get event bits in LSB
;
