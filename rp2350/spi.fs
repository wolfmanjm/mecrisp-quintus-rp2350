\ spix driver

#require gpio-pins.fs

$40080000 constant SPI0_BASE
$40088000 constant SPI1_BASE
\ choose which one we want
SPI1_BASE constant SPIn_BASE

  SPIn_BASE $00000000 + constant spi_SSPCR0
  SPIn_BASE $00000004 + constant spi_SSPCR1
  SPIn_BASE $00000008 + constant spi_SSPDR
  SPIn_BASE $0000000c + constant spi_SSPSR
  SPIn_BASE $00000010 + constant spi_SSPCPSR
  SPIn_BASE $00000014 + constant spi_SSPIMSC
  SPIn_BASE $00000018 + constant spi_SSPRIS
  SPIn_BASE $0000001c + constant spi_SSPMIS
  SPIn_BASE $00000020 + constant spi_SSPICR

\ Bitfields for spi_SSPCR0
  $0000000F 0 2constant m_spi_SSPCR0_DSS
  $00000003 4 2constant m_spi_SSPCR0_FRF
  1 6 lshift constant b_spi_SSPCR0_SPO
  1 7 lshift constant b_spi_SSPCR0_SPH
  $000000FF 8 2constant m_spi_SSPCR0_SCR

\ Bitfields for spi_SSPCR1
  1 0 lshift constant b_spi_SSPCR1_LBM
  1 1 lshift constant b_spi_SSPCR1_SSE
  1 2 lshift constant b_spi_SSPCR1_MS
  1 3 lshift constant b_spi_SSPCR1_SOD

\ Bitfields for spi_SSPDR
  $0000FFFF 0 2constant m_spi_SSPDR_DATA

\ Bitfields for spi_SSPSR
  1 0 lshift constant b_spi_SSPSR_TFE
  1 1 lshift constant b_spi_SSPSR_TNF
  1 2 lshift constant b_spi_SSPSR_RNE
  1 3 lshift constant b_spi_SSPSR_RFF
  1 4 lshift constant b_spi_SSPSR_BSY

\ Bitfields for spi_SSPCPSR
  $000000FF 0 2constant m_spi_SSPCPSR_CPSDVSR

\ Bitfields for spi_SSPIMSC
  1 0 lshift constant b_spi_SSPIMSC_RORIM
  1 1 lshift constant b_spi_SSPIMSC_RTIM
  1 2 lshift constant b_spi_SSPIMSC_RXIM
  1 3 lshift constant b_spi_SSPIMSC_TXIM

\ Bitfields for spi_SSPRIS
  1 0 lshift constant b_spi_SSPRIS_RORRIS
  1 1 lshift constant b_spi_SSPRIS_RTRIS
  1 2 lshift constant b_spi_SSPRIS_RXRIS
  1 3 lshift constant b_spi_SSPRIS_TXRIS

\ Bitfields for spi_SSPMIS
  1 0 lshift constant b_spi_SSPMIS_RORMIS
  1 1 lshift constant b_spi_SSPMIS_RTMIS
  1 2 lshift constant b_spi_SSPMIS_RXMIS
  1 3 lshift constant b_spi_SSPMIS_TXMIS

\ Bitfields for spi_SSPICR
  1 0 lshift constant b_spi_SSPICR_RORIC
  1 1 lshift constant b_spi_SSPICR_RTIC

$40020000 constant RESETS_RESET
$40020008 constant RESETS_RESET_DONE
1 lshift 18 constant RESET_SPI0
1 lshift 19 constant RESET_SPI1

1 constant GPIO_FUNC_SPI
150000000 constant FREQ_IN

\ cpol cpha
$00 constant SPI_MODE0
$01 constant SPI_MODE1
$10 constant SPI_MODE2
$11 constant SPI_MODE3

\ TODO select spi0 or 1
: spi1-show-pin. ( pin# -- )
	case
		 8 of ." MISO " endof
		12 of ." MISO " endof
        28 of ." MISO " endof
		11 of ." MOSI " endof
		15 of ." MOSI " endof
        27 of ." MOSI " endof
		10 of ." SCLK " endof
		14 of ." SCLK " endof
        26 of ." SCLK " endof
		." Invalid SPI1 pin " dup .
	endcase
;

\ checks the pin is valid for SPI1
\ TODO select spi0 or 1
: spi1-valid-pin? ( pin# -- flg )
	\ 8,12,28 MISO
	\ 11,15,27 MOSI
	\ 10,14,26 SCK
	dup 8 >= swap 15 <= and
;

\ set the pins used for SPI1 checks if they are valid for SPI1
: spi1-set-pins ( pin1# pin2# pin3# -- errflg )
	0 pick spi1-valid-pin?
	1 pick spi1-valid-pin? and
	2 pick spi1-valid-pin? and
	not if 2drop drop true exit then

	\ Configure GPIO pins as SPI function eg 10 (SCLK), 11 (MOSI), 12 (MISO)
	3 0 do GPIO_FUNC_SPI gpio-set-gpio-function loop
    false
;

\ TODO allow SPI0
: spi1-reset
	RESET_SPI1 RESETS_RESET bis!  \ RESETS_RESET_SPI1_BITS
	RESET_SPI1 RESETS_RESET bic!
	begin RESET_SPI1 RESETS_RESET_DONE bit@ until
;

: spi1-enable ( flg -- )
    b_spi_SSPCR1_SSE spi_SSPCR1 rot if bis! else bic! then
;

\ sets or clears a range of bits in addr
: bits! ( value mask pos addr -- )
    >r tuck         \ -- value pos mask pos
    lshift r@ bic!  \ clear mask first
    lshift r> bis!  \ set the value bits
;

0 variable spi1_prescale
0 variable spi1_postdiv
: spi1-set-baudrate ( baudrate -- )
	false spi1-enable

    \ Find smallest prescale value which puts output frequency in range of post-divide.
    \ Prescale is an even number from 2 to 254 inclusive.
     						\ -- baudrate
    256 spi1_prescale !
    255 2 do
    	dup 256 um* i 2+ s>d ud* FREQ_IN s>d 2swap d< if i spi1_prescale ! leave then
    2 +loop
    						\ -- baudrate
    spi1_prescale @ 254 > if ." baudrate too low" drop exit then

    \ Find largest post-divide which makes output <= baudrate. Post-divide is
    \ an integer in the range 1 to 256 inclusive.
    2 spi1_postdiv !
    2 256 do
    	spi1_prescale @ i 1- * FREQ_IN swap / over u> if i spi1_postdiv ! leave then
    -1 +loop
    								\ -- baudrate
    \ ." actual baudrate = " 	spi1_prescale @ spi1_postdiv @ * FREQ_IN swap / .	\ freq_in / (prescale * postdiv)

	spi1_prescale @ spi_SSPCPSR !					\ set prescale
	spi1_postdiv @ 1- $ff 8 spi_SSPCR0 bits! 		\ set postdiv bits (clear first)

	drop
	true spi1-enable
;

: spi-set-format ( databits SPIMODE -- )
	false spi1-enable
	swap 1- $0F and 						\ data bits
	over 1 rshift 6 lshift or 				\ cpol
	swap %01 and 7 lshift or 				\ cpha
	%11001111 0 spi_SSPCR0 bits!			\ clear bitmask and set new values
	true spi1-enable
;

: spi1-init ( baudrate -- )
	spi1-reset
	spi1-set-baudrate
	8 SPI_MODE0 spi-set-format
    true spi1-enable
;

: spi1-writable? ( -- flg ) %010 spi_SSPSR bit@ ;
: spi1-readable? ( -- flg ) %100 spi_SSPSR bit@ ;

: spi1-write-read ( n wrbuf rdbuf -- )
	>r >r dup  						\ -- rx_remaining tx_remaining
	begin 2dup or while 			\ while rx_remaining or tx_remaining
		dup spi1-writable? and 		\ tx_remaining && spi_is_writable && 			\ -- rx_remaining tx_remaining flg
		over 8 + 3 pick > and		\ (tx_remaining + fifo_depth) > rx_remaining
		if
			r@ c@ spi_SSPDR !		\ write data from wrbuf
			r> 1+ >r				\ wrbuf+=1
			1- 					 	\ tx_remaining-=1
		then
		over spi1-readable? and		\ rx_remaining && spi_is_readable				\ -- rx_remaining tx_remaining flg
		if
			spi_SSPDR @ 1 rpick c!	\ read data into rdbuf
			r> r> 1+ >r >r			\ rdbuf+=1
			swap 1- swap 			\ rx_remaining-=1
		then
	repeat
	rdrop rdrop
	2drop
;

: spi1-write ( n wrbuf -- )
	swap 0 do
		begin spi1-writable? until
		dup i + c@
        \ dup hex.
        spi_SSPDR !
	loop
	drop

	begin spi1-readable? while spi_SSPDR @	drop repeat
	begin $10 spi_SSPSR bit@ not until
	begin spi1-readable? while spi_SSPDR @	drop repeat
	1 spi_SSPICR !
;

: spi1-read ( n rdbuf -- )
	>r dup  						\ -- rx_remaining tx_remaining
	begin 2dup or while 			\ while rx_remaining or tx_remaining
		dup spi1-writable? and 		\ tx_remaining && spi_is_writable && 			\ -- rx_remaining tx_remaining flg
		over 8 + 3 pick > and		\ (tx_remaining + fifo_depth) > rx_remaining
		if 0 spi_SSPDR ! 1- then 	\ tx_remaining-=1
		over spi1-readable? and		\ rx_remaining && spi_is_readable				\ -- rx_remaining tx_remaining flg
		if
			spi_SSPDR @ r@ c! 		\ read data into rdbuf
			r> 1+ >r 				\ rdbuf+=1
			swap 1- swap 			\ rx_remaining-=1
		then
	repeat
	rdrop
	2drop
;

: spi1-write16 ( n d16 -- )
    dup $FF and swap 8 rshift    \ n lb hb
    rot
    0 do
        2dup
        begin spi1-writable? until
        spi_SSPDR !
        begin spi1-writable? until
        spi_SSPDR !
    loop
    2drop

    begin spi1-readable? while spi_SSPDR @ drop repeat
    begin $10 spi_SSPSR bit@ not until
    begin spi1-readable? while spi_SSPDR @ drop repeat
    1 spi_SSPICR !
;

\ test using GPIO pins on SPI1
\ 10     | SPI1 SCK
\ 11     | SPI1 MOSI
\ 12     | SPI1 MISO

8 buffer: wbuf
8 buffer: rbuf
: test-spi
	10 11 12 spi1-set-pins if ." invalid pins for SPI1" exit then
	cr ." Using pins: " 10 11 12 depth 0 do dup . spi1-show-pin. loop cr
	500000 spi1-init
	8 0 do i 1+ wbuf i + c! $a5 rbuf i + c! loop
	8 wbuf rbuf spi1-write-read
	8 0 do rbuf i + c@ hex. loop
	cr
;
