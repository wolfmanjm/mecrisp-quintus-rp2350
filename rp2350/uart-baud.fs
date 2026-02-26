\ set uart baudrate
$40070000 constant UART0_BASE
UART0_BASE $00000028 + constant uart0_UARTFBRD
UART0_BASE $00000024 + constant uart0_UARTIBRD
UART0_BASE $0000002c + constant uart0_UARTLCR_H
UART0_BASE $00000030 + constant uart0_UARTCR
\ Bitfields for uart0_UARTFBRD
$0000003F 0 2constant m_uart0_UARTFBRD_BAUD_DIVFRAC
\ Bitfields for uart0_UARTIBRD
$0000FFFF 0 2constant m_uart0_UARTIBRD_BAUD_DIVINT

: baudrate-divs ( baudrate -- ibrd fbrd )
    \ system clock assumed to be 150MHz
    150000000 8 * swap / 1+
    dup 7 rshift >r \ ibrd
    r@ 0= if drop rdrop 1 0 exit then
    r@ 65535 >= if drop rdrop 65535 0 exit then
    $7F and 1 rshift \ fbrd
    r> swap
;
: >xor ( x -- x ) %10 12 lshift bic %01 12 lshift or 1-foldable inline ;

: setbaudrate ( baud -- )
    baudrate-divs
    1 uart0_UARTCR bic!
    uart0_UARTFBRD !
    uart0_UARTIBRD !
    0 uart0_UARTLCR_H >xor !
    1 uart0_UARTCR bis!
;
