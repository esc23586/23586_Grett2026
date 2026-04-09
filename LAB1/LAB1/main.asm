/*
* LAB1.asm
*
* Creado:  03 de Febrero 2026
* Corregido 10 de Febrerro 2026
* Autor : Grettel Escobedo
* Descripción: Contador binario de 4 bits con antirrebote y led de carry
*		Cuenta según "Contador 1" los pulsos del botón, ya sea incrementar o decrementar. 
*		Según esto, cuenta en binario 
*/


/****************************************/

// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

/******** DEFINICIONES ********/
.def Contador = r16
.def Temp     = r17
.def D1       = r18
.def D2       = r19
.def Sel      = r20      ; 0 = Contador1, 1 = Contador2
.def Resultado = r21

/******** SRAM ********/
.dseg
Contador1: .byte 1
Contador2: .byte 1

.cseg
.org 0x0000

RJMP START
;=========================================

/****************************************/
START:
 
// Configuración de la pila
	LDI     R17, LOW(RAMEND)
	OUT     SPL, R17
	LDI     R17, HIGH(RAMEND)
	OUT     SPH, R17
/****************************************/
// Configuracion MCU (Entradas y Salidas)

	;  ; ----- PUERTO B -----; PB0–PB3 como salidas. LEDs para mi contador 1 
	; En este caso Pb0 es menos significativo. 
    ldi Temp, 0b00001111
    out DDRB, Temp
    clr Temp
    out PORTB, Temp

    ;------- Botones en PORTC---------
    clr Temp
    out DDRC, Temp
    ldi Temp, 0b00011011   ; PC0, PC1, PC3, PC4 pull-up
    out PORTC, Temp

	; ----LEDs de resultado en PORTD--
    ldi Temp, 0b00001111
    out DDRD, Temp
    clr Temp
    out PORTD, Temp

    ; ---Inicializar contadores---
    clr Temp
    sts Contador1, Temp
    sts Contador2, Temp
    clr Sel
	;------------------
    rcall LOAD_CONTADOR
    rcall MOSTRAR
	
/****************************************/
// Loop Infinito
MAIN_LOOP:

; Lectura de las entradas, en el registro de r17 variable temporal
;========= SUMA CONTADOR1 + CONTADOR2 (PC4) =========
    sbic PINC, PC4
    rjmp CHECK_SEL

    rcall DELAY_REBOTE

    lds Temp, Contador1
    lds Resultado, Contador2
    add Temp, Resultado
    andi Temp, 0x0F
    out PORTD, Temp

WAIT_SUM:
    sbis PINC, PC4
    rjmp WAIT_SUM
    rcall DELAY_REBOTE

    clr Temp
    out PORTD, Temp
    rjmp MAIN_LOOP


;========= CAMBIO DE CONTADOR (PC3) =========
CHECK_SEL:
    sbic PINC, PC3
    rjmp CHECK_INC

    rcall DELAY_REBOTE
    rcall SAVE_CONTADOR

    ldi Temp, 1
    eor Sel, Temp

WAIT_SEL:
    sbis PINC, PC3
    rjmp WAIT_SEL
    rcall DELAY_REBOTE

    rcall LOAD_CONTADOR
    rcall MOSTRAR
    rjmp MAIN_LOOP


;========= INCREMENTAR (PC0) =========
CHECK_INC:
    sbic PINC, PC0
    rjmp CHECK_DEC

    rcall DELAY_REBOTE
    inc Contador
    andi Contador, 0x0F
    rcall MOSTRAR
    rcall SAVE_CONTADOR

WAIT_INC:
    sbis PINC, PC0
    rjmp WAIT_INC
    rcall DELAY_REBOTE
    rjmp MAIN_LOOP


;========= DECREMENTAR (PC1) =========
CHECK_DEC:
    sbic PINC, PC1
    rjmp MAIN_LOOP

    rcall DELAY_REBOTE
    tst Contador
    breq NO_DEC
    dec Contador

NO_DEC:
    rcall MOSTRAR
    rcall SAVE_CONTADOR

WAIT_DEC:
    sbis PINC, PC1
    rjmp WAIT_DEC
    rcall DELAY_REBOTE
    rjmp MAIN_LOOP

/****************************************/


// NON-Interrupt subroutines
LOAD_CONTADOR:
    tst Sel
    brne LOAD_C2
    lds Contador, Contador1
    ret
LOAD_C2:
    lds Contador, Contador2
    ret

SAVE_CONTADOR:
    tst Sel
    brne SAVE_C2
    sts Contador1, Contador
    ret
SAVE_C2:
    sts Contador2, Contador
    ret

MOSTRAR:
    out PORTB, Contador
    ret
/****************************************/
// Interrupt routines
DELAY_REBOTE:
    ldi D1, 100
D1_LOOP:
    ldi D2, 100
D2_LOOP:
    dec D2
    brne D2_LOOP
    dec D1
    brne D1_LOOP
    ret

/****************************************/