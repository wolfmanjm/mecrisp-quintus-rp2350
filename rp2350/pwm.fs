\ Set for specified GPIO
3 constant PWM_PIN
$40028000 PWM_PIN 8 * + 4 + constant IO_BANK0_GPIO_N_CTRL
$40038000 PWM_PIN 4 * + 4 + constant PADS_BANK0_GPION
PWM_PIN 1 rshift 7 and constant PWM_SLICE               \ slice_num = ((gpio) >> 1u) & 7u;
$400a8000 PWM_SLICE $14 * + constant PWM_SLICE_ADDR
PWM_PIN 1 and 0<> constant PWM_B                          \ true if B channel else it is A channel
$00000000 constant PWM_CSR
$00000004 constant PWM_DIV
$0000000C constant PWM_CC
$00000010 constant PWM_TOP

32768 constant PWM_TOP_SETTING
$0049 constant PWM_DIV_SETTING      \ set to 1000Hz
\ $05B9 constant PWM_DIV_SETTING    \ 50Hz

\ set duty cycle to us high if 1KHz frequency
: pwm-set-us ( us -- )
    PWM_TOP_SETTING * 1000 /        \ register setting TOP
    PWM_B if 16 lshift then         \ A or B (B is << 16)
    PWM_SLICE_ADDR PWM_CC + !
;

\ set duty cycle to %
: pwm-set-dc ( pcnt -- )
    PWM_TOP_SETTING * 100 /        \ register setting TOP
    PWM_B if 16 lshift then         \ A or B (B is << 16)
    PWM_SLICE_ADDR PWM_CC + !
;

: pwm-init
    \ Configure GPIO pin PWM_PIN to func 4 PWM
    4 IO_BANK0_GPIO_N_CTRL !            \ Set to PWM function
    1 6 lshift 1 or PADS_BANK0_GPION !  \ Enable IE, slew fast, disable pad isolation
    \ set TOP to 32768 and set DIV to 0x0049 = 1000Hz period
    PWM_TOP_SETTING PWM_SLICE_ADDR PWM_TOP + !
    PWM_DIV_SETTING PWM_SLICE_ADDR PWM_DIV + !
    \ set to 0% duty cycle
    0 PWM_B if 16 lshift then  \ A or B (B is << 16)
    PWM_SLICE_ADDR PWM_CC + !
    1 PWM_SLICE_ADDR PWM_CSR + !    \ enable
;

: pwm-start
    1 PWM_SLICE_ADDR PWM_CSR + bis!
;

: pwm-stop
    1 PWM_SLICE_ADDR PWM_CSR + bic!
;
