/*
* NombreProgra.asm
*
* Creado: 
* Autor : Grettel Escobedo 23586
* Descripción: Implemente un contador binario de 4 bits, con lógica on-change y pullups internos
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)
.cseg

;========================
; Registros
;========================
	.def ContadorLED   = r16
	;.def Contador7seg  = r20
	.def Temp          = r17
	.def D1            = r18
	.def D2            = r19

	.org 0x0000; Se incia aqui para guardar.
	rjmp SETUP

	.org PCINT1addr;Pueba, luego cambiar a un nombre más significativo; revisar si no sobreescribo
    rjmp PCINT_ISR; mi ubicación al saltar en la etiqueta. 

 /****************************************/
 ;================
 ;  -----RESET----
 ;================

 RESET:
	CLI

 /****************************************/
// Configuración de la pila
SETUP:

	LDI     R16, LOW(RAMEND)
	OUT     SPL, R16
	LDI     R16, HIGH(RAMEND)
	OUT     SPH, R16


;========================================================
; Tablita para los valores del display
;========================================================
; revisar si no me afecta el que no utilizaré letras
	Table7seg:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71


/****************************************/
//  ---Puertos- MCU--- Salidas y Entradas.

;CONTADOR (PreLAB):
; Se establece como salidas puerto B salidas (LEDs)
    ldi Temp, 0b00001111; 0x0F
    out DDRB, Temp

; Apagar LEDs AL iniciar con el código 
    clr Temp
    out PORTB, Temp


; ---------PC0 y PC1 entradas con pull-up-----
; Lo hago de esta forma porque es más rapido, además me trajo complicaciones con la asignación de binario.

    cbi DDRC, PC0				; clear bit, voy a la dirección y le digo que es 0
    cbi DDRC, PC1
	; se activan los pullup
    sbi PORTC, PC0				; le asigno 1, para que se active
    sbi PORTC, PC1

;--------------------------------
; Habilitar Pin Change Interrupt
;--------------------------------
    ldi temp, (1<<PCIE1)
    sts PCICR, temp

    ldi temp, (1<<PCINT8)|(1<<PCINT9)
    sts PCMSK1, temp


	/*
; --------------Configuración de los Pines para el puerto D-----
	LDi Temp, 0xFF				;0b11111111, se activaron todos, debido a que se usará el utlimo para la alarma.
	OUT DDRD, Temp				; Se les asigna a la dirección
	CLR Temp					; limpio mi variable (setear a cero)
	OUT PORTD,Temp				; Les mando 0 voltios para empezar. 
	*/
	
;--------------------------------
; Inicializar contador
;--------------------------------
    clr ContadorLED
    out PORTB, ContadorLED

    SEI


/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP    MAIN_LOOP
/****************************************/
// NON-Interrupt subroutines
MOSTRAR:

    ; ---- LEDs (PORTB) ----
    mov Temp, ContadorLED
    andi Temp, 0x0F
    out PORTB, Temp

	RET



;==============================
; SUBRUTINA ANTIRREBOTE:
;==============================
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


/****************************************/
// Interrupt routines


/****************************************/