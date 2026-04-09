;.include "m328pdef.inc"

;========================
; Registros
;========================
.def Contador = r16
.def Temp     = r17
.def D1       = r18    ; contador de overflows
.def D2       = r19

.org 0x0000
    rjmp START

;========================
START:
;---- Stack ----
    ldi Temp, LOW(RAMEND)
    out SPL, Temp
    ldi Temp, HIGH(RAMEND)
    out SPH, Temp

;========================
; ---Puertos-
;========================

; PB0–PB3 salidas (LEDs)
    ldi Temp, 0b00001111
    out DDRB, Temp

; Apagar LEDs AL iniciar con el código 
    clr Temp
    out PORTB, Temp

; PC0 y PC1 entradas con pull-up
; lo hago de esta forma porque es más rapido, además me trajo complicaciones con la asignación de binario
    cbi DDRC, PC0
    cbi DDRC, PC1
    sbi PORTC, PC0
    sbi PORTC, PC1

;========================
; Timer0
;========================
; Modo normal, prescaler = 64
    ldi Temp, (1<<CS01)|(1<<CS00)
    out TCCR0B, Temp

    clr D1            ; contador de cuantos overflows van ocurriendo. 

;========================
; Inicialización
;========================
    clr Contador
    rcall MOSTRAR

;========================
MAIN_LOOP:

;========= BOTÓN INC =========
    sbic PINC, PC0; si no esta presionado--- salta
    rjmp CHECK_DEC

    rcall DELAY_REBOTE; mi antirrebote

    inc Contador
	; se busca que cuabndo este llegue a 16 este regrese a cero
    cpi Contador, 16
    brlo INC_OK
    clr Contador          ; overflow
INC_OK:
    rcall MOSTRAR; en teoria este es el reflejo en mi contador

WAIT_INC: ; aqui meramente solo espero a que se deje de presionar el botón para volver a leer.
    sbis PINC, PC0
    rjmp WAIT_INC
    rcall DELAY_REBOTE
    rjmp MAIN_LOOP

;========= BOTÓN DEC =========
; Misma lógica que al in crementar
CHECK_DEC:
    sbic PINC, PC1
    rjmp TIMER_CHECK

    rcall DELAY_REBOTE
    tst Contador
    brne DEC_OK
    ldi Contador, 15      ; underflow
    rjmp DEC_DONE
DEC_OK:
    dec Contador
DEC_DONE:
    rcall MOSTRAR

WAIT_DEC:
    sbis PINC, PC1
    rjmp WAIT_DEC
    rcall DELAY_REBOTE
    rjmp MAIN_LOOP

;========= TIMER0 =========
TIMER_CHECK:
    in Temp, TIFR0 ; revisa si ocurrio over, sino este sigue de largo
    sbrs Temp, TOV0
    rjmp MAIN_LOOP

    ; limpiar flag overflow, en teoria aqui deberia de limpiarse pero no lo hace.
    ldi Temp, (1<<TOV0)
    out TIFR0, Temp

    inc D1
    cpi D1, 98
    brlo MAIN_LOOP

    clr D1
    inc Contador
    cpi Contador, 16
    brlo TIMER_OK
    clr Contador          ; overflow
TIMER_OK:
    rcall MOSTRAR
    rjmp MAIN_LOOP

;========================
; Mostrar contador
;========================
MOSTRAR:
    mov Temp, Contador
    andi Temp, 0x0F
    out PORTB, Temp
    ret

;========================
; Delay antirrebote
;========================
DELAY_REBOTE:
    ldi D1, 100
DLY1:
    ldi D2, 100
DLY2:
    dec D2
    brne DLY2
    dec D1
    brne DLY1
    ret
