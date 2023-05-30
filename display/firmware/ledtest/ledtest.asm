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
; Pins

    ; port A
    HP2   equ 2
    HPWO  equ 4
    HSYNC equ 5
    HISA  equ 6
    HIWA  equ 7
    
    ; port C
    DSD   equ 0
    DSC   equ 1
    DLC   equ 4
    DOE   equ 5


;===========================================================
; RAM Map

;-----------------------------------------------------------
; bank 0  0x20 - 0x6F

	; write_lcd
    wlcd_ctr    equ 0x20
    wlcd_inst   equ 0x21
    wlcd_data   equ 0x22

    ; host
    host_mode   equ 0x30
    host_din    equ 0x31
    host_porta  equ 0x32
    host_skip   equ 0x33
    host_bit    equ 0x34
    host_digit  equ 0x35

    scratch     equ 0x4E
    int_scratch equ 0x4F

	lcd_row_1   equ 0x50 ; - 0x5F
    lcd_row_2   equ 0x60 ; - 0x6F

;-----------------------------------------------------------
; bank 1  0xA0 - 0xBF

;-----------------------------------------------------------
; cross-bank row mapped at:
; bank 0  0x70 - 0x7F
; bank 1  0xF0 - 0xFF

	; interrupt vector
    int_temp_w      equ 0x70
    int_temp_status	equ 0x71
    int_temp_fsr    equ 0x72

;===========================================================
; EEPROM Map

    ee_lcd_init     equ 0x00 ; - 0x1F

;===========================================================
; Defines

    ; bits for host_mode
    MODE_CMD    equ 0
    MODE_DIGIT  equ 1
    MODE_HIGH   equ 2
    MODE_ANN    equ 3
    MODE_SKIP   equ 4

    ; host protocol commands
    CMD_LOW     equ 0x0A
    CMD_HIGH    equ 0x1A
    CMD_ANN     equ 0xBC

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
    ldr     FSR, W
    str     int_temp_fsr
    bcr     STATUS, PAGE
    
int_sync:
    btss    INTCON, PAIF
    ljump   int_clock
    
    btss    PORTA, HSYNC
    ljump   int_sync_data
    
int_sync_cmd:
    ldwi    1<<MODE_CMD
    str     host_mode
    clrr    host_din

    ljump   int_end

int_sync_data:
    ldr     host_din, W
    sublw   CMD_LOW
    btsc    STATUS, Z
    ljump   int_cmd_low
    
    ldr     host_din, W
    sublw   CMD_HIGH
    btsc    STATUS, Z
    ljump   int_cmd_high

    ldr     host_din, W
    sublw   CMD_ANN
    btsc    STATUS, Z
    ljump   int_cmd_ann

    ljump   int_end

int_cmd_low:
    ldwi    1<<MODE_DIGIT | 1<<MODE_SKIP
    str     host_mode
    ldwi    2
    str     host_bit
    ldwi    0x5B
    str     host_digit

    ljump   int_end

int_cmd_high:
    ldwi    1<<MODE_DIGIT | 1<<MODE_HIGH | 1<<MODE_SKIP
    str     host_mode
    ldwi    2
    str     host_bit
    ldwi    0x5B
    str     host_digit

    ljump   int_end
    
int_cmd_ann:
    ldwi    1<<MODE_ANN | 1<<MODE_SKIP
    str     host_mode
    ldwi    2
    str     host_bit
    ldwi    0x60
    str     host_digit

    ljump   int_end


int_clock:
    btss    INTCON, INTF
    ljump   int_end
    
    rlr     PORTA, W        ; put IWA in C
    str     int_scratch
    btsc    host_mode, MODE_CMD
    rlr     int_scratch, R  ; put ISA in C (only in command mode)
    rrr     host_din, R     ; shift din right, set din(7) to C

    decrsz  host_bit, R
    ljump   int_end
    
    ldwi    4
    str     host_bit

    btss    host_mode, MODE_SKIP
    ljump   int_data

    bcr     host_mode, MODE_SKIP
    clrr    host_din
    ljump   int_end

int_data:
    ldr     host_digit, W
    str     FSR

    btsc    host_mode, MODE_DIGIT
    ljump   int_data_digit
    
    btsc    host_mode, MODE_ANN
    ljump   int_data_ann
    
    ljump   int_end

    
int_data_digit:
    btsc    host_mode, MODE_HIGH
    ljump   int_data_digit_high
    
int_data_digit_low:
    ldr     INDF, W
    andwi   0xF0
    swapr   host_din, R
    iorwr   host_din, W
    str     INDF
    ljump   int_data_digit_end

int_data_digit_high:
    ; put din[5:4] in digit[5:4]
    ldr     INDF, W
    andwi   0x0F
    str     int_scratch
    ldr     host_din, W
    andwi   0x30
    iorwr   int_scratch, W
    str     INDF

    ; put din[7:6] in extra[2:1]
    ldwi    0x10
    addwr   FSR, R  ; switch to the extras row
    swapr   host_din, R
    rrr     host_din, W
    andwi   0x06
    str     host_din
    ldr     INDF, W
    andwi   0xF9
    iorwr   host_din, W
    str     INDF

int_data_digit_end:
    clrr    host_din

    decr    host_digit, R
    btsc    host_digit, 4
    clrr    host_mode  ; done if < 0x60

    ljump   int_end    
    

int_data_ann:
    swapr   host_din, R

int_data_ann_loop:
    rrr     host_din, R
    ldwi    0x01
    andwr   STATUS, W
    str     int_scratch
    ldr     INDF, W
    andwi   0xFC
    iorwr   int_scratch, W
    str     INDF

    incr    FSR, R    
    decrsz  host_bit, R
    ljump   int_data_ann_loop
    
    ldwi    4
    str     host_bit
    ldr     FSR, W
    str     host_digit

int_end:
    bcr     INTCON, PAIF
    bcr     INTCON, INTF
    ldr     int_temp_fsr, W
    str     FSR
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
	ldr     PORTA, W; preload PAI latch
    clrr	PORTC   ; preset all outputs off
    clrr    T0CON0  ; T0: disable, from inst. clock

    bsr     STATUS, PAGE

    ldwi    0x71
    str     OSCCON  ; select 16 MHz internal oscillator
    ldwi    0x44    ; PA2 interrupt on rising edge
    str     OPTION  ; T0 from internal, scaler for T0, scaler = 32
    ldwi    0x33
    str		WPUC    ; enable weak pull-up on port C
    ldwi    0xCC
    str     TRISC   ; set port C to output
    ldwi    1<<HSYNC
    str     IOCA    ; int. on change for SYNC (PA5)

    bcr     STATUS, PAGE
    
    ldwi    0x50
    str     FSR
    ldwi    0x20 ; space
loop_init_1:
    str     INDF
    incr    FSR, R
    btsc    FSR, 4 ; while < 0x60
    ljump   loop_init_1
    
loop_init_2:
    ldwi    0x30 ; zero
    str     INDF
    incr    FSR, R
    ldwi    0x6C
    subwr   FSR, W
    btss    STATUS, Z
    ljump   loop_init_2

    ldwi    0x20 ; space    
    str     0x6C
    str     0x6D
    str     0x6E
    str     0x6F

    ldwi    1<<GIE | 1<<INTE | 1<<PAIE
    str     INTCON
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
