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

    ; port A - host
    HP2   equ 2
    HP1   equ 3
    HPWO  equ 4
    HSYNC equ 5
    HISA  equ 6
    HIWA  equ 7

    ; port C - display
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
    int_temp_status equ 0x71
    int_temp_fsr    equ 0x72

;===========================================================
; EEPROM Map

    ee_lcd_init     equ 0x00 ; - 0x1F

;===========================================================
; Defines

    ; bits for host_mode
    MODE_READ   equ 0
    MODE_CMD    equ 1
    MODE_SKIP   equ 2
    MODE_DIGIT  equ 3
    MODE_HIGH   equ 4
    MODE_ANN    equ 5

    ; host protocol commands
    CMD_LOW     equ 0x0A
    CMD_HIGH    equ 0x1A
    CMD_ANN     equ 0xBC

;===========================================================
; Boot Vector

    org     0x0000
    goto    main

;===========================================================
; Interrupt Vector

    org     0x0004
    movwf   int_temp_w
    swapf   STATUS, w  ; movf sets Z, swapf doesn't
    movwf   int_temp_status
    movf    FSR, w
    movwf   int_temp_fsr
    clrf    STATUS

    ; when PWO is low, reset state and ignore everything
    btfsc   PORTA, HPWO
    goto    int_sync
    clrf    host_mode
    goto    int_end


int_sync:
    btfss   PORTA, HSYNC
    goto    int_sync_data

int_sync_cmd:
    ; if we were already in command mode, just handle data
    btfsc   host_mode, MODE_CMD
    goto    int_shift

    ; enter command mode
    movlw   1<<MODE_READ | 1<<MODE_CMD
    movwf   host_mode
    clrf    host_din
    goto    int_shift

int_sync_data:
    ; if we were already not in command mode, just handle data
    btfss   host_mode, MODE_CMD
    goto    int_shift

    ; we're switching from command to data mode
    ; set up for the given command
    movf    host_din, w
    sublw   CMD_LOW
    btfsc   STATUS, Z
    goto    int_cmd_digit_low

    movf    host_din, w
    sublw   CMD_HIGH
    btfsc   STATUS, Z
    goto    int_cmd_digit_high

    movf    host_din, w
    sublw   CMD_ANN
    btfsc   STATUS, Z
    goto    int_cmd_ann

    ; unsupported command, ignore until the next command
    clrf    host_mode
    goto    int_end

int_cmd_digit_low:
    movlw   1<<MODE_READ | 1<<MODE_DIGIT | 1<<MODE_SKIP
    movwf   host_mode
    movlw   2
    movwf   host_bit
    movlw   0x5B
    movwf   host_digit
    goto    int_shift

int_cmd_digit_high:
    movlw   1<<MODE_READ | 1<<MODE_DIGIT | 1<<MODE_HIGH | 1<<MODE_SKIP
    movwf   host_mode
    movlw   2
    movwf   host_bit
    movlw   0x5B
    movwf   host_digit
    goto    int_shift

int_cmd_ann:
    movlw   1<<MODE_READ | 1<<MODE_ANN | 1<<MODE_SKIP
    movwf   host_mode
    movlw   2
    movwf   host_bit
    movlw   0x6B
    movwf   host_digit
    goto    int_shift


int_shift:
    ; don't bother reading if we don't need to
    btfss   host_mode, MODE_READ
    goto    int_end

    ; shift a data bit into the buffer
    rlf     PORTA, w        ; put IWA in C
    movwf   int_scratch
    btfsc   host_mode, MODE_CMD
    rlf     int_scratch, f  ; put ISA in C (only in command mode)
    rrf     host_din, f     ; shift din right, set din(7) to C

    decfsz  host_bit, f
    goto    int_end

    movlw   4
    movwf   host_bit

    ; if we were skipping leader bits
    ; switch to normal read mode but ignore this bit
    btfss   host_mode, MODE_SKIP
    goto    int_data
    bcf     host_mode, MODE_SKIP
    clrf    host_din
    goto    int_end

int_data:
    movf    host_digit, w
    movwf   FSR

    btfsc   host_mode, MODE_DIGIT
    goto    int_data_digit

    btfsc   host_mode, MODE_ANN
    goto    int_data_ann

    goto    int_end


int_data_digit:
    btfsc   host_mode, MODE_HIGH
    goto    int_data_digit_high

int_data_digit_low:
    movf    INDF, w
    andlw   0xF0
    swapf   host_din, f
    iorwf   host_din, w
    movwf   INDF
    goto    int_data_digit_end

int_data_digit_high:
    ; put din[5:4] in digit[5:4]
    movf    INDF, w
    andlw   0x0F
    movwf   int_scratch
    movf    host_din, w
    andlw   0x30
    iorwf   int_scratch, w
    movwf   INDF

    ; the host sends 0x40 - 0x5F as 0x00 - 0x1F
    ; add back the missing 0x40 bit
    btfss   INDF, 5
    bsf     INDF, 6

    ; put din[7:6] in extra[1:0]
    movlw   0x10
    addwr   FSR, f  ; switch to the extras row
    movf    INDF, w
    andlw   0xFC
    movwf   int_scratch
    swapf   host_din, f
    rrf     host_din, f
    rrf     host_din, w
    andlw   0x03
    iorwf   int_scratch, w
    movwf   INDF

int_data_digit_end:
    clrf    host_din

    decf    host_digit, f
    movlw   0x50
    subwf   host_digit, w
    btfss   STATUS, C
    clrf    host_mode  ; done after 0x50

    goto    int_end


int_data_ann:
    rrf     host_din, f

int_data_ann_loop:
    movf    INDF, w
    andlw   0xFB
    movwf   int_scratch
    rrf     host_din, f
    movf    host_din, w
    andlw   0x04
    iorwf   int_scratch, w
    movwf   INDF

    decf    FSR, f
    decfsz  host_bit, f
    goto    int_data_ann_loop

    clrf    host_din
    movlw   4
    movwf   host_bit
    movf    FSR, w
    movwf   host_digit

    ; done after 0x60
    movlw   0x60
    subwf   host_digit, w
    btfss   STATUS, C
    clrf    host_mode


int_end:
    bcf     INTCON, INTF
    movf    int_temp_fsr, w
    movwf   FSR
    swapf   int_temp_status, w
    movwf   STATUS
    swapf   int_temp_w, f
    swapf   int_temp_w, w
    retfie


;===========================================================
; Program Section

;-----------------------------------------------------------
wait_digit:
    btfss   INTCON, T0IF
    goto    wait_digit
    clrf    TMR0
    bcf     INTCON, T0IF
    return

;-----------------------------------------------------------
write_lcd:
    ; set up status read
    movlw   0x21
    movwf   PORTC       ; R/W=R(1), OE off, clock low
    bsf     PORTC, 1    ; clock high
    movlw   0x20
    movwf   PORTC       ; RS=IR(0), OE off, clock low
    bsf     PORTC, 1    ; clock high
    bcf     PORTC, 1    ; clock low
    bsf     PORTC, 1    ; clock high
    bcf     PORTC, 1    ; clock low
    bsf     STATUS, 5   ; page 1
    bsf     TRISC, 0    ; data as input
    bcf     STATUS, 5   ; page 0
    bsf     PORTC, 4    ; enable
    nop
    nop                 ; wait for data valid >= 160 ns (250 ns)

    ; wait for the busy flag to clear
write_lcd_wait:
    btfsc   PORTC, 0
    goto    write_lcd_wait

    bcf     PORTC, 4    ; disable
    bsf     STATUS, PAGE
    bcf     TRISC, 0    ; data as output
    bcf     STATUS, PAGE

    movlw   8
    movwf   wlcd_ctr

write_lcd_shift:
    ; shift out data (big-endian) and set clock low
    rlf     wlcd_data, f  ; puts the high-order bit in C
    movf    STATUS, w   ; get C into W
    andlw   0x01        ; keep only C as the DSD pin
    iorlw   0x20        ; OE off
    movwf   PORTC
    bsf     PORTC, 1    ; clock high

    decfsz  wlcd_ctr, 1
    goto    write_lcd_shift

    movlw   0x20
    movwf   PORTC       ; R/W=0(W), OE off, clock low
    bsf     PORTC, 1    ; clock high
    movf    wlcd_inst, 0
    iorlw   0x20
    movwf   PORTC       ; register select, OE off, clock low
    bsf     PORTC, 1    ; clock high
    bcf     PORTC, 1    ; clock low
    bsf     PORTC, 1    ; clock high
    clrf    PORTC       ; clock low, output on
    bsf     PORTC, 4    ; enable
    nop
    nop
    nop                 ; enable hold time >= 230 ns (375 ns)
    bcf     PORTC, 4    ; disable
    nop                 ; data hold time >= 10 na (125 ns)

    return


;-----------------------------------------------------------
main:
    clrf    PORTC   ; preset all outputs off
    clrf    T0CON0  ; T0: disable, from inst. clock

    bsf     STATUS, PAGE

    movlw   0x71
    movwf   OSCCON  ; select 16 MHz internal oscillator
    movlw   0x44    ; PA2 interrupt on rising edge
    movwf   OPTION  ; T0 from internal, scaler for T0, scaler = 32
    movlw   0x33
    movwf   WPUC    ; enable weak pull-up on port C
    movlw   0xCC
    movwf   TRISC   ; set port C to output
    movlw   1<<HSYNC

    bcf     STATUS, PAGE

    movlw   0x50
    movwf   FSR
    movlw   0x20 ; space
loop_init_1:
    movwf   INDF
    incf    FSR, f
    btfsc   FSR, 4 ; while < 0x60
    goto    loop_init_1

loop_init_2:
    clrf    INDF
    incf    FSR, f
    btfss   FSR, 4 ; while < 0x70
    goto    loop_init_2


    movlw   1<<GIE | 1<<INTE
    movwf   INTCON
    bsf     T0CON0, T0ON

    ; initialize display hardware
    clrf    wlcd_inst        ; instruction register
    movlw   0x38
    movwf   wlcd_data
    call    write_lcd       ; function set: 8-bit, 2 lines
    movlw   0x01
    movwf   wlcd_data
    call    write_lcd       ; clear display
    movlw   0x0C
    movwf   wlcd_data
    call    write_lcd       ; display on

    movlw   0x40
    movwf   wlcd_data
    call    write_lcd       ; set CGRAM address 0x00
    bsf     wlcd_inst, 0    ; data register
    bsf     STATUS, PAGE
    clrf    EEADR
cgram_loop:
    bsf     EECON1, RD
    movf    EEDAT, w
    bcf     STATUS, PAGE
    movwf   wlcd_data
    call    write_lcd
    bsf     STATUS, PAGE
    incf    EEADR, f
    movlw   0x40
    subwf   EEADR, w
    btfss   STATUS, C
    goto    cgram_loop

    bcf     STATUS, PAGE

main_loop:
    clrf    wlcd_inst        ; instruction register
    movlw   0x80
    movwf   wlcd_data
    call    write_lcd       ; set DDRAM address 0x00 (start of first row)
    bsf     wlcd_inst, 0    ; data register

    movlw   lcd_row_1
    movwf   FSR
loop_lcd_row1:
    call    wait_digit
    movf    INDF, w
    movwf   wlcd_data
    call    write_lcd
    incf    FSR, f
    btfss   FSR, 5          ; FSR >= 0x60
    goto    loop_lcd_row1

    clrf    wlcd_inst        ; instruction register
    movlw   0xC0
    movwf   wlcd_data
    call    write_lcd       ; set DDRAM address 0x40 (start of second row)
    bsf     wlcd_inst, 0    ; data register

loop_lcd_row2:
    call    wait_digit
    movf    INDF, w
    movwf   wlcd_data
    call    write_lcd
    incf    FSR, f
    btfss   FSR, 4          ; FSR >= 0x70
    goto    loop_lcd_row2

    goto    main_loop

end