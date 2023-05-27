//Project: ledtest.prj
// Device: FT60F22X
// Memory: Flash 2KX14b, EEPROM 256X8b, SRAM 128X8b

#include  <FT60F12X.INC>

;===========================================================
;RAM DEFINE
    W_TMP        EQU        0x70
    S_TMP        EQU        0x71

    wlcd_ctr    equ 0x20
    wlcd_inst   equ 0x21
    wlcd_data   equ 0x22

;===========================================================

    org     0x0000  ; boot vector
    ljump   main

;-----------------------------------------------------------
    org     0x0004  ; interrupt vector
    str     W_TMP
    swapr   STATUS,W
    str     S_TMP

    swapr   S_TMP, 0
    str     STATUS
    swapr   W_TMP, 1
    swapr   W_TMP, 0
    reti



;-----------------------------------------------------------
write_lcd:
    ; set up status read
    ldwi    0x21
    str     PORTC       ; R/W=1(R) and clock low
    bsr     PORTC, 4    ; clock high
    ldwi	0x20
    str     PORTC       ; RS=0(IR) and clock low
    bsr     PORTC, 4    ; clock high
    bcr		PORTC, 4	; clock low
    bsr     PORTC, 4    ; clock high
    bcr		PORTC, 4	; clock low
    
    bsr     STATUS, 5   ; page 1
    bsr     TRISC, 0    ; data as input
    bcr     STATUS, 5   ; page 0
    
    bsr     PORTC, 1    ; enable
    nop
    nop                 ; wait for data valid >= 160 ns (250 ns)

    ; wait for the busy flag to clear
write_lcd_wait:
    btsc    PORTC, 0
    ljump   write_lcd_wait

    bcr     PORTC, 1    ; disable

    bsr     STATUS, 5   ; page 1
    bcr     TRISC, 0    ; data as output
    bcr     STATUS, 5   ; page 0

    ldwi    8
    str     wlcd_ctr

write_lcd_shift:
    ; shift out data and set clock low
    rlr     wlcd_data, 1
    ldr     wlcd_data, 0
    andwi   0x01
    iorwi	0x20
    str     PORTC

    bsr     PORTC, 4    ; clock low

    decrsz  wlcd_ctr, 1
    ljump   write_lcd_shift

    ldr     wlcd_inst, 0
    iorwi	0x20
    str     PORTC       ; register select and clock low
    bsr     PORTC, 4    ; clock high
    ldwi	0x20
    str     PORTC       ; R/W=0(W) and clock low
    bsr     PORTC, 4    ; clock high
    bcr		PORTC, 4	; clock low
    bsr     PORTC, 4    ; clock high
    clrr    PORTC       ; clock low, output on
    bsr     PORTC, 1    ; enable
    nop
    nop                 ; enable hold time >= 230 ns (250 ns)
    bcr     PORTC, 1    ; disable

    ret


;-----------------------------------------------------------
main:
	clrr	PORTC

    bsr     STATUS, 5 ; page 1

    ; select 16 MHz internal oscillator
    ldwi    0x71
    str     OSCCON

    ; set all of port C to output
    clrr    TRISC

    bcr     STATUS, 5 ; page 0

    ; clear display
    clrr    wlcd_inst
    clrr    wlcd_data
    lcall   write_lcd

    ; display on
    ldwi    0x0C
    str     wlcd_data
    lcall   write_lcd

    bsr     wlcd_inst, 0 ; data register

    ldwi    0x48    ; "H"
    str     wlcd_data
    lcall   write_lcd

    ldwi    0x65    ; "e"
    str     wlcd_data
    lcall   write_lcd

    ldwi    0x6C    ; "l"
    str     wlcd_data
    lcall   write_lcd
    lcall   write_lcd

    ldwi    0x6F    ; "o"
    str     wlcd_data
    lcall   write_lcd

    end

;-----------------------------------------------------------
    end
