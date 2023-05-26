//Project: ledtest.prj
// Device: FT60F22X
// Memory: Flash 2KX14b, EEPROM 256X8b, SRAM 128X8b

#include  <FT60F12X.INC>

;===========================================================
;RAM DEFINE
    W_TMP        EQU        0x70
    S_TMP        EQU        0x71

;===========================================================

    org     0x0000  ; boot vector
    ljump   main

    org     0x0004  ; interrupt vector
    str     W_TMP
    swapr   STATUS,W
    str     S_TMP
    ljump   interrupt

;-----------------------------------------------------------
main:
	; select 16 MHz internal oscillator
    bsr		STATUS, 5 ; page 1
    ldwi	0x71
    str		OSCCON
    bcr		STATUS, 5 ; page 0

	; set all of port C to output
    clrw
    str		PORTC
    ctlio	7 ; TRISC
    

square:
    bsr     PORTC, 0
    nop
    bcr     PORTC, 0
    ljump   square


;-----------------------------------------------------------
interrupt:
    swapr   S_TMP, 0
    str     STATUS
    swapr   W_TMP, 1
    swapr   W_TMP, 0
    reti
;-----------------------------------------------------------
    end
