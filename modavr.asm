;-------------------------------------------------------------------------------
; Sony PSX modchip based on Atmel ATtiny13 MCU, v1.0
; by m.d./XDS, 2010 (maddevmail@gmail.com)
;
; Pin connections:
; 1 - n/c
; 2 - n/c
; 3 - n/c
; 4 - GND
; 5 - GATE
; 6 - DATA
; 7 - n/c
; 8 - VCC
;
; Fuse bit settings:
;
;	CKSEL0     = P (0) (internal RC oscillator @ 9.6 MHz)
;	CKSEL1     = . (1)
;	SUT0       = . (1) (14 CK + 4 ms startup time)
;	SUT1       = P (0)
;	CKDIV8     = P (0) (divide system clock by 8)
;	WDTON      = P (0) (watchdog timer is always on)
;	EESAVE     = . (1)
;	SPIEN      = P (0)

;	RSTDISBL   = . (1)
;	BODLEVEL0  = . (1) (2.7 V brown-out detection threshold)
;	BODLEVEL1  = P (0)
;	DWEN       = . (1)
;	SELFPRGEN  = . (1)
;
; This circuit uses an on-board RC oscillator to clock MCU. For more predictable
; operation it is recommended to tune it accurately to 9.6 MHz via setting OSCCAL
; register value in the initialization section

.include "tn13def.inc"

; mod-chip pins
.equ GATE	= PB0
.equ DATA	= PB1

.def _0		= r0
.def tmp	= r16
.def i		= r17
.def char	= r18

.cseg
.org 0
	rjmp reset

;-------------------------------------------------------------------------------
; Timer interrupt handler - called 1000 times per sec

.org OC0Aaddr
; decrease counter used in 'do_delay' routine
	sbiw xh:xl,1
	reti

;-------------------------------------------------------------------------------
; Delay handling macro

; delay_ms <n> - wait for <n> milliseconds
.macro delay_ms
	ldi xl,low(@0)
	ldi xh,high(@0)
	rcall do_delay
.endm

; do_delay - idle delay
; Input: X = number of milliseconds to wait
do_delay:
	out TCNT0,_0
	ldi tmp,1<<OCF0A
	out TIFR0,tmp
check_x:
	cp xl,_0
	cpc xh,_0
	breq exit_delay
	wdr
	sei
	sleep
	cli
	rjmp check_x
exit_delay:
	ret

;-------------------------------------------------------------------------------
; Data output handling routines

; tx_byte - transmit a byte
; Input: char = byte to transmit

tx_byte:
	ldi i,11
	clc			; start "zero" bit
tx_bit:
	brcs tx_one
; transmit "zero" bit - release DATA line
	cbi DDRB,DATA
	rjmp tx_next
tx_one:
; transmit "one" bit - pull DATA line down
	sbi DDRB,DATA
tx_next:
; 250 bps stream - 4 ms per bit
	delay_ms 4
	sec			; stop "one" bits
	ror char
	dec i
	brne tx_bit
	ret

; tx_string - transmit 4-byte region string
; Input: Z -> string data in the flash

tx_string:
; interstring delay - 72 ms
	delay_ms 72
	lpm char,z+
	rcall tx_byte
	lpm char,z+
	rcall tx_byte
	lpm char,z+
	rcall tx_byte
	lpm char,z+
	rcall tx_byte	
	ret

;-------------------------------------------------------------------------------
; Device initialization

reset:
; rollback prevention (see AVR123 application note for details)
	in tmp,MCUSR
	clr _0
	out MCUSR,_0
	andi tmp,0xF
halt:
	breq halt

; tune RC oscillator
	ldi tmp,0x67
	out OSCCAL,tmp

; enable SLEEP instruction
	ldi tmp,1<<SE
	out MCUCR,tmp

; initialize stack
	ldi tmp,RAMEND
	out SPL,tmp

; reduce power consumption
	sbi ACSR,ACD
	ldi tmp,~(1<<DATA|1<<GATE)
	out PORTB,tmp

; configure timer: 1000 interrupts per second
	ldi tmp,1<<WGM01
	out TCCR0A,tmp
	ldi tmp,149
	out OCR0A,tmp
	ldi tmp,1<<CS01
	out TCCR0B,tmp

	ldi tmp,1<<OCIE0A
	out TIMSK0,tmp

; initial delay - 50 ms
	delay_ms 50

; pull DATA line low
	sbi DDRB,DATA

	delay_ms 850

; pull GATE line low
	sbi DDRB,GATE

	delay_ms 14

; infinite loop bruteforcing region codes
cheat:
	ldi zl,low(strings<<1)
	ldi zh,high(strings<<1)
	rcall tx_string
	rcall tx_string
	rcall tx_string
	rjmp cheat

;-------------------------------------------------------------------------------
; Table of region codes

strings:
	.db "SCEI"	; Japan / NTSC
	.db "SCEA"	; US / NTSC
	.db "SCEE"	; Europe / PAL

author:
	.db "m.d./XDS, 2010"
