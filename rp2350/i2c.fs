\ i2c.fs I2C for the rp2350
\ currently I2C0 on pins 4 (SDA) and 5 (SCL) only

$40090000 constant I2C0_BASE
\ =========================== I2C0 =========================== \
I2C0_BASE $000 + constant _IC_CON
I2C0_BASE $004 + constant _IC_TAR
I2C0_BASE $010 + constant _IC_DATA_CMD
I2C0_BASE $014 + constant _IC_SS_SCL_HCNT \ Standard Speed I2C Clock SCL High Count Register
I2C0_BASE $018 + constant _IC_SS_SCL_LCNT \ Standard Speed I2C Clock SCL Low Count Register
I2C0_BASE $01C + constant _IC_FS_SCL_HCNT \ Fast Mode or Fast Mode Plus I2C Clock SCL High Count Register
I2C0_BASE $020 + constant _IC_FS_SCL_LCNT \ Fast Mode or Fast Mode Plus I2C Clock SCL Low Count Register
I2C0_BASE $02C + constant _IC_INTR_STAT
I2C0_BASE $030 + constant _IC_INTR_MASK
I2C0_BASE $034 + constant _IC_RAW_INTR_STAT
I2C0_BASE $038 + constant _IC_RX_TL \ I2C Receive FIFO Threshold Register
I2C0_BASE $03C + constant _IC_TX_TL \ I2C Transmit FIFO Threshold Register
I2C0_BASE $040 + constant _IC_CLR_INTR \ Clear Combined and Individual Interrupt Register
I2C0_BASE $044 + constant _IC_CLR_RX_UNDER \ Clear RX_UNDER Interrupt Register
I2C0_BASE $048 + constant _IC_CLR_RX_OVER \ Clear RX_OVER Interrupt Register
I2C0_BASE $04C + constant _IC_CLR_TX_OVER \ Clear TX_OVER Interrupt Register
I2C0_BASE $050 + constant _IC_CLR_RD_REQ \ Clear RD_REQ Interrupt Register
I2C0_BASE $054 + constant _IC_CLR_TX_ABRT \ Clear TX_ABRT Interrupt Register
I2C0_BASE $058 + constant _IC_CLR_RX_DONE \ Clear RX_DONE Interrupt Register
I2C0_BASE $05C + constant _IC_CLR_ACTIVITY \ Clear ACTIVITY Interrupt Register
I2C0_BASE $060 + constant _IC_CLR_STOP_DET \ Clear STOP_DET Interrupt Register
I2C0_BASE $064 + constant _IC_CLR_START_DET \ Clear START_DET Interrupt Register
I2C0_BASE $068 + constant _IC_CLR_GEN_CALL \ Clear GEN_CALL Interrupt Register
I2C0_BASE $06C + constant _IC_ENABLE \ I2C Enable Register
I2C0_BASE $070 + constant _IC_STATUS
I2C0_BASE $074 + constant _IC_TXFLR
I2C0_BASE $078 + constant _IC_RXFLR
I2C0_BASE $07C + constant _IC_SDA_HOLD
I2C0_BASE $080 + constant _IC_TX_ABRT_SOURCE
I2C0_BASE $088 + constant _IC_DMA_CR
I2C0_BASE $08C + constant _IC_DMA_TDLR \ DMA Transmit Data Level Register
I2C0_BASE $090 + constant _IC_DMA_RDLR \ I2C Receive Data Level Register
I2C0_BASE $094 + constant _IC_SDA_SETUP
I2C0_BASE $09C + constant _IC_ENABLE_STATUS
I2C0_BASE $0A0 + constant _IC_FS_SPKLEN
I2C0_BASE $0A8 + constant _IC_CLR_RESTART_DET

\ =========================== RESETS =========================== \
$40020000 constant RESETS_RESET
$40020008 constant RESETS_RESET_DONE
$10       constant RESETS_RESET_I2C0_BITS

$40028000 constant IO_BANK0_GPIO0_STATUS \ GPIO status
$40028004 constant IO_BANK0_GPIO0_CTRL \ GPIO control including function select and overrides.
$40028008 constant IO_BANK0_GPIO1_STATUS \ GPIO status
$4002800C constant IO_BANK0_GPIO1_CTRL \ GPIO control including function select and overrides.
$40028024 constant IO_BANK0_GPIO4_CTRL \ GPIO control including function select and overrides.
$4002802C constant IO_BANK0_GPIO5_CTRL

$40038004 constant PADS_BANK0_GPIO0 \ Pad control register
$40038008 constant PADS_BANK0_GPIO1 \ Pad control register
$40038014 constant PADS_BANK0_GPIO4 \ Pad control register
$40038018 constant PADS_BANK0_GPIO5 \ Pad control register

100000 constant I2C_BAUDRATE

: i2c-reserved-addr ( addr -- flg ) $78 and dup 0= swap $78 = or ;

: disable-i2c
	%1 _IC_ENABLE bic!
	\ begin %1 _IC_ENABLE_STATUS bit@ 0= until
;

: enable-i2c
	%1 _IC_ENABLE bis!
	\ begin %1 _IC_ENABLE_STATUS bit@ until
;

: i2c-busy? ( -- flg )
	%100 _IC_ENABLE_STATUS bit@
;

: i2c-init
	\ Reset the I2C0 peripheral
	RESETS_RESET_I2C0_BITS RESETS_RESET bis!
	RESETS_RESET_I2C0_BITS RESETS_RESET bic!
	begin RESETS_RESET_I2C0_BITS RESETS_RESET_DONE bit@ until

	\ Configure GPIO pins 4 (SDA) and 5 (SCL)
    3 IO_BANK0_GPIO4_CTRL ! \ Set to I2C function
    3 IO_BANK0_GPIO5_CTRL !

    1 2 lshift 1 6 lshift or PADS_BANK0_GPIO4 !  \ Enable pull-ups and IE
    1 2 lshift 1 6 lshift or PADS_BANK0_GPIO5 !

    \ Set up I2C Control register Master mode, 7-bit addressing,
    \ I2C_IC_CON_TX_EMPTY, I2C_IC_CON_IC_RESTART_EN_BITS, fast-mode
    $100 $20 or $40 or $01 or $02 1 lshift or _IC_CON !

    \ Set FIFO watermarks to 1 to make things simpler. This is encoded by a register value of 0.
	0 _IC_RX_TL !
	0 _IC_TX_TL !

	\ DMA stuff
	$02 $01 or _IC_DMA_CR !

    \ Set baud rate (Assuming 150MHz system clock)
	\ uint period = (freq_in + baudrate / 2) / baudrate;
    \ uint lcnt = period * 3 / 5; // oof this one hurts
    \ uint hcnt = period - lcnt;
    150000000 I2C_BAUDRATE 2/ + I2C_BAUDRATE / dup 	\ period
    \ dup 125000000 swap / ." baudrate = " .          \ debug
    3 * 5 / >r r@ _IC_FS_SCL_LCNT !   			\ lcnt
    r@ - _IC_FS_SCL_HCNT ! 						\ hcnt
    \ fs_spklen = lcnt < 16 ? 1 : lcnt / 16;
	r@ 16 < if 1 else r@ 16 / then _IC_FS_SPKLEN !
	rdrop

	\ sda_tx_hold_count = ((freq_in * 3) / 10000000) + 1;
	150000000 3 * 10000000 / 1+ $06 and _IC_SDA_HOLD !

    \ Enable the I2C controller
    enable-i2c
;

: i2c-set-address ( addr -- )
	disable-i2c _IC_TAR ! enable-i2c
;

\ write a buffer of data with stop at the end
: i2c-writebuf ( n buf addr -- errflg )
	2 pick 1 < if 2drop drop true exit then \ check >= 1
	i2c-set-address
	over 0 do 								\ -- n buf
		dup i + c@ 							\ -- n buf data
		2 pick 1- i = if $200 or then \ if last byte issue stop
		_IC_DATA_CMD !
		\ wait for transmit
		begin %10000 _IC_RAW_INTR_STAT bit@ until

		\ check for errors
		_IC_TX_ABRT_SOURCE @ if _IC_CLR_TX_ABRT @ drop true else false then
		if \ there was an error
			begin $200 _IC_RAW_INTR_STAT bit@ until  \ wait for stop
			_IC_CLR_STOP_DET @ drop
			2drop unloop true exit
		then
	loop
	begin $200 _IC_RAW_INTR_STAT bit@ until  \ wait for stop
	_IC_CLR_STOP_DET @ drop
	2drop
	false
;

\ write a buffer of data with no stop so transaction can continue
: i2c-writebuf-nostop ( n buf addr -- errflg )
	2 pick 1 < if 2drop drop true exit then \ check >= 1
	i2c-set-address
	swap 0 do 								\ -- buf
		dup i + c@ 							\ -- buf data
		_IC_DATA_CMD !
		\ wait for transmit
		begin %10000 _IC_RAW_INTR_STAT bit@ until

		\ check for errors
		_IC_TX_ABRT_SOURCE @ if _IC_CLR_TX_ABRT @ drop true else false then
		if \ there was an error
			begin $200 _IC_RAW_INTR_STAT bit@ until  \ wait for stop
			_IC_CLR_STOP_DET @ drop
			drop unloop true exit
		then
	loop
	drop
	false
;

: _i2c-dorcv ( buf cmd -- errflg )
		_IC_DATA_CMD !
		\ wait for recieve or error
		begin _IC_TX_ABRT_SOURCE @	_IC_RXFLR @ or until
		\ check for errors
		_IC_TX_ABRT_SOURCE @ if	_IC_CLR_TX_ABRT @ drop drop true exit then
		_IC_DATA_CMD @	\ read data byte
		swap c!		  		\ store in buffer
		false
;

false variable _i2c-restartflg

\ read a buffer of data normal start/stop
: _i2c-read ( n buf -- errflg )
	over 1- -rot						\ -- n-1 n buf
	swap 0 do  							\ -- n-1 buf
		\ not sure why but pico sdk does this - wait for space in tx fifo
		begin 16 _IC_TXFLR @ - until
		over i = if $200 else 0 then			 		\ stop flag if last byte
		i 0= if _i2c-restartflg @ if $400 or then then	\ restart flag
		$100 or  										\ read cmd
														\ -- n-1 buf cmd
		over i + swap									\ next buffer place
		_i2c-dorcv if 2drop unloop true exit then
	loop
	2drop
	false
;

: i2c-readbuf ( n buf addr -- errflg )
	2 pick 1 < if 2drop drop true exit then \ check >= 1
	i2c-set-address
	false _i2c-restartflg !
	_i2c-read
;

\ restart a read issued after writebufnostop to read a bunch of registers
\ NOTE address has already been set in writebufnostop
: i2c-readbuf-restart ( n buf -- errflg )
	over 1 < if 2drop true exit then 	\ check >= 1
	true _i2c-restartflg !
	_i2c-read
;

: i2c-deviceready? ( addr -- flg )
	i2c-set-address

	$100 			\ I2C_IC_DATA_CMD_CMD_BITS
	$200 or 		\ last byte so issue stop
	_IC_DATA_CMD !

	\ wait for recieve or error
	begin
		_IC_TX_ABRT_SOURCE @	\ error?
		_IC_RXFLR @ or			\ receive available?
	until

	\ check for errors
	_IC_TX_ABRT_SOURCE @ if
		_IC_CLR_TX_ABRT @ drop false
	else
		_IC_DATA_CMD @ drop
		true
	then
;

\ --------------------- Bus scan stuff ------------------
\ print hex value n with x bits
: N#h. ( n bits -- )
	begin
		4 -
		2dup rshift $F and .digit emit
		dup 0=
	until 2drop
;

: 2#h. ( char -- )
	8 N#h.
;

\ scan and report all I2C devices on the bus
: i2cScan. ( -- )
    i2c-init
    128 0 do
        cr i 2#h. ." :"
        16 0 do  space
          i j + i2c-deviceready? if i j + 2#h. else ." --" then
          \ i j + 2#h.
          2 ms
          key? if unloop unloop exit then
        loop
    16 +loop
    cr
;

