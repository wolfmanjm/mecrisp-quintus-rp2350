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

    dup 3 rshift 2 lshift _PROC0_INTE0 +  \ register offset for this gpio -- eventmask pin# regoff
    swap %0111 and 2 lshift         \ (gpio mod 8) * 4 -- eventmask regoff shift
    rot swap lshift                 \ shift event into correct position
    swap !                          \ set event bits FIXME do HWSET not write
;

0 variable irq_count

: my-handler
    meinext@ 2 rshift IO_IRQ_BANK0 <> if unhandled exit then
    \ its our interrupt
    1 irq_count +!
    \ clear the interrupt source
    b_INTR_EDGE_HIGH b_INTR_EDGE_LOW or 14 gpio-ack-irq
;

: test
    \ set pin to input with pullup
    5 GPIO_14_CTRL !
    1 3 lshift 1 6 lshift or PADS_BANK0_GPIO14 !  \ Enable pull-ups and IE

    \ enable the peripheral IRQ for pin 14 with edge high and low
    b_INTR_EDGE_HIGH b_INTR_EDGE_LOW or 14 gpio-irq-enable
    \ enable the BANK0 IRQ
    IO_IRQ_BANK0 enable-irq

    ['] my-handler irq-collection !

    EINT

    begin
        wfi
        irq_count @ . cr
    key? until
;



