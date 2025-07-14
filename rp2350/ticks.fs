\ NOTE presumes ticks have been setup in the clocks.s

$D0000000 constant SIO_BASE
SIO_BASE $000001a4 + constant sio_MTIME_CTRL
SIO_BASE $000001b0 + constant sio_MTIME
SIO_BASE $000001b4 + constant sio_MTIMEH
SIO_BASE $000001b8 + constant sio_MTIMECMP
SIO_BASE $000001bc + constant sio_MTIMECMPH

: delayus  ( us -- )
    sio_MTIME @ +
    begin
        dup
        sio_MTIME @
        u<=             \ NOTE this will give a short timeout if mtime+tmo has wrapped
    until
    drop
;

: delayms ( ms -- )
    1000 * delayus
;

: ticks-us ( -- tickcnt ) sio_MTIME @ ;
