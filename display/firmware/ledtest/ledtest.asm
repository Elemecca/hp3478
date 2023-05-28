// Device: FT60F12X
// Memory: Flash 2Kx14b, EEPROM 256x8b, SRAM 128x8b
// Options Setup:
//   CPB:       Disable
//   MCLRE:     PA5
//   PWRTEB:    Disable
//   WDTE:      Disable
//   FOSC:      INTOSCIO
//   TSEL:      2T
//   FCMEN:     Disable
//   IESO:      Disable
//   RDCTRL:    Latch
//   LVREN:     Enable
//   RBTENB:    Enable
//   LVRS:      3.6V
//   LVDDEB:    Disable

#include  <FT60F12X.INC>

;===========================================================
; RAM Map

;-----------------------------------------------------------
; bank 0  0x20 - 0x6F

	; write_lcd
    wlcd_ctr    equ 0x20
    wlcd_inst   equ 0x21
    wlcd_data   equ 0x22


	lcd_row_1   equ 0x50 ; - 0x5F
    lcd_row_2   equ 0x60 ; - 0x6F

;-----------------------------------------------------------
; bank 1  0xA0 - 0xBF

;-----------------------------------------------------------
; cross-bank row mapped at:
; bank 0  0x70 - 0x7F
; bank 1  0xF0 - 0xFF

	; interrupt handler
    int_temp_w      equ 0x70
    int_temp_status	equ 0x71

;===========================================================
; EEPROM Map

    ee_lcd_init     equ 0x00 ; - 0x1F

;===========================================================
; Boot Vector

    org     0x0000
    ljump   main

;===========================================================
; Interrupt Vector

    org     0x0004
    str     int_temp_w
    swapr   STATUS, W  ; ldr sets Z, swapr doesn't
    str     int_temp_status

    swapr   int_temp_status, W
    str     STATUS
    swapr   int_temp_w, R
    swapr   int_temp_w, W
    reti

;===========================================================
; Program Section

;-----------------------------------------------------------
wait_digit:
    btss    INTCON, T0IF
    ljump   wait_digit
    clrr    TMR0
    bcr     INTCON, T0IF
    ret

;-----------------------------------------------------------
write_lcd:
    ; set up status read
    ldwi    0x21
    str     PORTC       ; R/W=R(1), OE off, clock low
    bsr     PORTC, 1    ; clock high
    ldwi	0x20
    str     PORTC       ; RS=IR(0), OE off, clock low
    bsr     PORTC, 1    ; clock high
    bcr		PORTC, 1	; clock low
    bsr     PORTC, 1    ; clock high
    bcr		PORTC, 1	; clock low
    bsr     STATUS, 5   ; page 1
    bsr     TRISC, 0    ; data as input
    bcr     STATUS, 5   ; page 0
    bsr     PORTC, 4    ; enable
    nop
    nop                 ; wait for data valid >= 160 ns (250 ns)
    
    ; wait for the busy flag to clear
write_lcd_wait:
    btsc    PORTC, 0
    ljump   write_lcd_wait

    bcr     PORTC, 4    ; disable
    bsr     STATUS, PAGE
    bcr     TRISC, 0    ; data as output
    bcr     STATUS, PAGE

    ldwi    8
    str     wlcd_ctr

write_lcd_shift:
    ; shift out data (big-endian) and set clock low
    rlr     wlcd_data, R  ; puts the high-order bit in C
    ldr     STATUS, W   ; get C into W
    andwi   0x01        ; keep only C as the DSD pin
    iorwi	0x20        ; OE off
    str     PORTC
    bsr     PORTC, 1    ; clock high

    decrsz  wlcd_ctr, 1
    ljump   write_lcd_shift

    ldwi	0x20
    str     PORTC       ; R/W=0(W), OE off, clock low
    bsr     PORTC, 1    ; clock high
    ldr     wlcd_inst, 0
    iorwi	0x20
    str     PORTC       ; register select, OE off, clock low
    bsr     PORTC, 1    ; clock high
    bcr		PORTC, 1	; clock low
    bsr     PORTC, 1    ; clock high
    clrr    PORTC       ; clock low, output on
    bsr     PORTC, 4    ; enable
    nop
    nop
    nop                 ; enable hold time >= 230 ns (375 ns)
    bcr     PORTC, 4    ; disable
    nop                 ; data hold time >= 10 na (125 ns)

    ret


;-----------------------------------------------------------
main:
	clrr	PORTC   ; preset all outputs off
    clrr    T0CON0  ; T0: disable, from inst. clock
    bsr     STATUS, PAGE
    ldwi    0x71
    str     OSCCON  ; select 16 MHz internal oscillator
    ldwi    0x04
    str     OPTION  ; T0 from internal, scaler for T0, scaler = 32
    ldwi    0x33
    str		WPUC    ; enable weak pull-up on port C
    ldwi    0xCC
    str     TRISC   ; set port C to output

    ; initialize display RAM from EEPROM
	ldwi    0x70
    str     FSR
    ldwi    0x20
    str     EEADR
loop_load_lcd:
    decr	FSR, R
    decr    EEADR, R
    bsr     EECON1, RD
    ldr     EEDAT, W
    str     INDF
	ldr     EEADR, R
    btss    STATUS, Z
    ljump   loop_load_lcd

    bcr     STATUS, PAGE

    bsr     T0CON0, T0ON


    ; initialize display hardware
    clrr    wlcd_inst		; instruction register
    ldwi    0x38
    str     wlcd_data
    lcall   write_lcd       ; function set: 8-bit, 2 lines
    ldwi    0x01
    str     wlcd_data
    lcall   write_lcd       ; clear display
    ldwi    0x0C
    str     wlcd_data
    lcall   write_lcd       ; display on

main_loop:
	clrr    wlcd_inst		; instruction register
    ldwi    0x80
    str     wlcd_data
    lcall   write_lcd       ; set DDRAM address 0x00 (start of first row)
    bsr     wlcd_inst, 0    ; data register

	ldwi	lcd_row_1
    str     FSR
loop_lcd_row1:
    call    wait_digit
    ldr     INDF, W
    str     wlcd_data
    lcall   write_lcd
    incr    FSR, R
    btss    FSR, 5          ; FSR >= 0x60
    ljump   loop_lcd_row1

	clrr    wlcd_inst		; instruction register
    ldwi    0xC0
    str     wlcd_data
    lcall   write_lcd       ; set DDRAM address 0x40 (start of second row)
    bsr     wlcd_inst, 0    ; data register

loop_lcd_row2:
    call    wait_digit
    ldr     INDF, W
    str     wlcd_data
    lcall   write_lcd
    incr    FSR, R
    btss    FSR, 4          ; FSR >= 0x70
    ljump   loop_lcd_row2


    ljump   main_loop
    end
