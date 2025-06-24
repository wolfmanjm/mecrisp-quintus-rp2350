#require gpio-irq.fs

\ Test gpio irq
$40028000 constant IO_BANK0_BASE
IO_BANK0_BASE 14 8 * + 4 + constant GPIO_14_CTRL

21 constant IO_IRQ_BANK0

$4003803C constant PADS_BANK0_GPIO14 \ Pad control register

0 variable irq_count

: my-handler
    meinext@ 2 rshift IO_IRQ_BANK0 <> if unhandled exit then
    \ its our interrupt
    \ check the actual pins and event. If it isn't this pin then leave
    14 gpio-irq-status dup 0= if drop unhandled exit then
    \ clear the actual interrupt source
    14 gpio-ack-irq

    \ increment count
    1 irq_count +!
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



