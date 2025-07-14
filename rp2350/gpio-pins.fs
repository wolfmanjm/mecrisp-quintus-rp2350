\ gpio-simple.fs

$40028000 constant IO_BANK0_BASE
$40038000 constant PADS_BANK0_BASE
$D0000000 constant SIO_BASE

SIO_BASE $00000000 + constant sio_CPUID
SIO_BASE $00000004 + constant sio_GPIO_IN
SIO_BASE $00000010 + constant sio_GPIO_OUT
SIO_BASE $00000018 + constant sio_GPIO_OUT_SET
SIO_BASE $00000020 + constant sio_GPIO_OUT_CLR
SIO_BASE $00000028 + constant sio_GPIO_OUT_XOR
SIO_BASE $00000030 + constant sio_GPIO_OE
SIO_BASE $00000038 + constant sio_GPIO_OE_SET
SIO_BASE $00000040 + constant sio_GPIO_OE_CLR
SIO_BASE $00000048 + constant sio_GPIO_OE_XOR

\ Bitfields for PADS_BANK0_BASE
1 0 lshift constant b_pad_GPIO_SLEWFAST
1 1 lshift constant b_pad_GPIO_SCHMITT
1 2 lshift constant b_pad_GPIO_PDE
1 3 lshift constant b_pad_GPIO_PUE
$00000003 4 2constant m_pad_GPIO_DRIVE
1 6 lshift constant b_pad_GPIO_IE
1 7 lshift constant b_pad_GPIO_OD
1 8 lshift constant b_pad_GPIO_ISO

\ helper to convert pin# to bit mask
: gpio-setbit ( pin# -- pinmask ) 1 swap lshift ;  \ Calculates the value for bit 0 (LSB) to bit 31 (MSB)

\ Pad-Bank control
: gpio-padRegister ( pin# -- Address )           \ Calculates the PadsRegister address
  2 lshift 4 +                              \ Starts at BASE + 4 with pin0, Base + 8 pin1 etc
  PADS_BANK0_BASE +
;

: gpio-set-gpio-function ( pin# fnc -- )
    >r
    dup gpio-padRegister b_pad_GPIO_IE swap bis!    \ enable input
    dup gpio-padRegister b_pad_GPIO_OD swap bic!    \ output disable off
    dup 8 * 4 + IO_BANK0_BASE + r> swap !           \ Set to GPIO function
    gpio-padRegister b_pad_GPIO_ISO swap bic!       \ clear pad isolation
;

\ set pin to output, using similar sequence as SDK
: pin-output ( pin# -- )
    dup gpio-setbit dup sio_GPIO_OE_CLR ! sio_GPIO_OUT_CLR !
    dup 5 gpio-set-gpio-function
    gpio-setbit sio_GPIO_OE_SET !
;

\ set pin to input
: pin-input ( pin# -- )
    dup gpio-setbit dup sio_GPIO_OE_CLR ! sio_GPIO_OUT_CLR !
    dup 5 gpio-set-gpio-function
    gpio-setbit sio_GPIO_OE_CLR !
;

\ set output pin to opendrain
: pin-opendrain ( pin# -- ) gpio-padRegister b_pad_GPIO_OD swap bis! ;

\ set input pin to pull up, disable pull down
: pin-pu ( pin# -- ) gpio-padRegister dup b_pad_GPIO_PUE swap bis! b_pad_GPIO_PDE swap bic! ;

\ set input pin to pull down, disable pullup
: pin-pd ( pin# -- ) gpio-padRegister dup b_pad_GPIO_PDE swap bis! b_pad_GPIO_PUE swap bic! ;

: pin-high   ( pin# -- ) gpio-setbit sio_GPIO_OUT_SET ! ;
: pin-low    ( pin# -- ) gpio-setbit sio_GPIO_OUT_CLR ! ;
: pin-toggle ( pin# -- ) gpio-setbit sio_GPIO_OUT_XOR ! ;

\ set given pin to value
: pin-set ( value pin# -- ) swap if pin-high else pin-low then ;

\ is given pin set
: pin-set? ( pin# -- t/f ) gpio-setbit sio_GPIO_IN bit@ ;
