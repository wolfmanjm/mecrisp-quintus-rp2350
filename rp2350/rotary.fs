#require gpio-irq.fs
#require cycles.fs

\ Rotary encoder on irq pins

$40028000 constant IO_BANK0_BASE
IO_BANK0_BASE 14 8 * + 4 + constant GPIO_14_CTRL
IO_BANK0_BASE 15 8 * + 4 + constant GPIO_15_CTRL
21 constant IO_IRQ_BANK0

$4003803C constant PADS_BANK0_GPIO14 \ Pad control register
$40038040 constant PADS_BANK0_GPIO15 \ Pad control register

$D0000000 constant SIO_BASE
SIO_BASE $004 + constant GPIO_IN       \ Input value for GPIO pins

\ derived from the arduino library Rotary.cpp
$00 constant DIR_NONE
$10 constant DIR_CW
$20 constant DIR_CCW

\ full step table
$00 constant R_START
$01 constant R_CW_FINAL
$02 constant R_CW_BEGIN
$03 constant R_CW_NEXT
$04 constant R_CCW_BEGIN
$05 constant R_CCW_FINAL
$06 constant R_CCW_NEXT

14 constant enca_pin
15 constant encb_pin

\ Emulate c, which is not available in hardware on some chips.
0 variable c,collection
: ec, ( c -- )
    c,collection @ ?dup
    if $FF and swap 8 lshift or h,
        0 c,collection !
    else
        $100 or c,collection !
    then
;
: ecalign ( -- ) c,collection @ if 0 ec, then ;

: create-enc-table
    <builds
        \ ttable[7][4]
        \ R_START
        R_START ec,    R_CW_BEGIN ec,  R_CCW_BEGIN ec, R_START ec,
        \ R_CW_FINAL
        R_CW_NEXT ec,  R_START ec,     R_CW_FINAL ec,  R_START DIR_CW or ec,
        \ R_CW_BEGIN
        R_CW_NEXT ec,  R_CW_BEGIN ec,  R_START ec,     R_START ec,
        \ R_CW_NEXT
        R_CW_NEXT ec,  R_CW_BEGIN ec,  R_CW_FINAL ec,  R_START ec,
        \ R_CCW_BEGIN
        R_CCW_NEXT ec, R_START ec,     R_CCW_BEGIN ec, R_START ec,
        \ R_CCW_FINAL
        R_CCW_NEXT ec, R_CCW_FINAL ec, R_START ec,     R_START DIR_CCW or ec,
        \ R_CCW_NEXT
        R_CCW_NEXT ec, R_CCW_FINAL ec, R_CCW_BEGIN ec, R_START ec,
        ecalign
    does> -rot 4 * + + c@
;

create-enc-table enc_table

0 variable enc-state
0 variable enc-count

: read-pin ( pin# -- 1|0 )
    1 swap lshift GPIO_IN bit@ if 1 else 0 then
;

: process ( -- enc-state )
    \ Grab pin-state of input pins.
    enca_pin read-pin 1 lshift encb_pin read-pin or \ pin-state
                                                    \ Determine new enc-state from the pins and state table.
    enc-state @ $0F and enc_table dup enc-state !      \ enc-state = ttable[enc-state & 0xf][pin-state]
    $30 and                                         \ Return emit bits, ie the generated event.
;

: enc-irq
    process dup DIR_CW = if
        1 enc-count +! drop
    else
        DIR_CCW = if
            -1 enc-count +!
        then
    then
;

\ this handles multiple interrupts
: my-handler
    begin
        meinext@ dup 0< if drop exit then               \ if MSB bit set then all irqs are handled

        \ make sure it is IO IRQ
        2 rshift IO_IRQ_BANK0 <> if unhandled exit then \ is it an IO IRQ

        \ check if it is one of our two pins
        enca_pin gpio-irq-status ?dup if
            \ clear the actual interrupt source
            enca_pin gpio-ack-irq
        else
            encb_pin gpio-irq-status ?dup if
                encb_pin gpio-ack-irq
            else
                \ it isn't either one of our pins
                unhandled
                exit
            then
        then
        enc-irq
    again
;

: encoder-init
    R_START enc-state !
    0 enc-count !

    \ set pin to input with pullup
    5 GPIO_14_CTRL !
    1 3 lshift 1 6 lshift or PADS_BANK0_GPIO14 !  \ Enable pull-ups and IE
    5 GPIO_15_CTRL !
    1 3 lshift 1 6 lshift or PADS_BANK0_GPIO15 !  \ Enable pull-ups and IE

    \ enable the peripheral IRQ for pin 14 & 15 with edge high and low
    b_INTR_EDGE_HIGH b_INTR_EDGE_LOW or enca_pin gpio-irq-enable
    b_INTR_EDGE_HIGH b_INTR_EDGE_LOW or encb_pin gpio-irq-enable

    \ set global irq handler
    ['] my-handler irq-collection !

    \ enable the BANK0 IRQ
    IO_IRQ_BANK0 enable-irq

    EINT
;

0 variable last-enc
: test-enc
    encoder-init
    enc-count @ last-enc !
    begin
        last-enc @ enc-count @ <> if enc-count @ dup last-enc ! . cr then
        200 ms
    key? until

    IO_IRQ_BANK0 disable-irq
    ['] unhandled irq-collection !
;
