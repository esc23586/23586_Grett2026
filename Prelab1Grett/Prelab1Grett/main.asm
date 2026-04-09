/*
* LAB1.asm
*
* Creado:  03 de Febrero 2026
* Corregido 10 de Febrerro 2026
* Autor : Grettel Escobedo
* Descripción: Contador binario de 4 bits con antirrebote y led de carry
*		Cuenta según "Contador 1" los pulsos del botón, ya sea incrementar o decrementar. 
*		Según esto, cuenta en binario y al haber overflow o underflow enciende carry.
*/


/****************************************/

// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg


.def Contador1 = r16
.def Temp	=	r17
.def D1		=	r18
.def D2		=	r19

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

    ; ----- PUERTO B -----; PB0–PB3 como salidas. LEDs para mi contador 1 
	; En este caso Pb0 es menos significativo. 
	LDI Temp, 0b00001111
	OUT DDRB, Temp

	; Inicialmente apagar LEDs--- Así  estará apagado hasta de inicio
	LDI Temp, 0x00
	OUT PORTB, Temp; Aqui les doy el apagon


	; ----- PUERTO C -----; PC0 y PC1 como entradas (botones)
	cbi DDRC, PC0
	; Activar pull-up internos en PC0 y PC1.
    sbi PORTC, PC0        

	; ----- PUERTO D -----
	; PD1 como salida (LED de carry) En este caso  D2 será donde esté el led, por ahora.
	; En todo caso solo se cambairia a pd0 en caso de ser necesario. 
	/*
	LDI r17, 0b00000100
	OUT DDRD, r17

	; Apagar LED de carry al inicio.
	LDI r17, 0x00
	OUT PORTD, r17

	;------------------
	*/
	clr Contador1          ; contador = 0
    rcall MOSTRAR
	
/****************************************/
// Loop Infinito
MAIN_LOOP:

; A partir de aqui r16 solo será para mi contador en binario
; Lectura de las entradas, en el registro de r17

	 sbic PINC, PC0
	 rjmp MAIN_LOOP
	 rjmp BOTON1_PRESIONADO
	;Por ello hay que revisar la bandera z puesto que esta será 1. osea z==1

	/*
	IN  R17, PINC; Leo Nuevamente el estado actual de los pines C
	ANDI R17,  0b00000010 ; Aqui leo PC1
	BREQ BOTON2_PRESIONADO   ; mismo que en linea 85
    RJMP MAIN_LOOP
	*/
;------Cuando el botón esté presionado-----------
; incrementar
BOTON1_PRESIONADO:
	RCALL DELAY_REBOTE ; evitamos el botonazo

    INC Contador1 ;Incrementar
	ANDI Contador1, 0x0F   ; limitar a 4 bits osea los primeros 4 encendidos
    RCALL MOSTRAR; Se  manda el dato al port B. y se debería mostrar en los leds 
	
ESPERAR_SOLTAR_INC:
	SBIS PINC, PC0
    RJMP ESPERAR_SOLTAR_INC

	RCALL DELAY_REBOTE; solo por curiosidad, tal vez es demaciado rapido u algo. 
	RJMP MAIN_LOOP

/*
; Decrementar
BOTON2_PRESIONADO:
	RCALL DELAY_REBOTE ; evitamos el botonazo

    CPI Contador1, 0;decrementar
    BREQ NO_DECREMENTAR
    DEC Contador1

NO_DECREMENTAR:
    OUT PORTB, Contador1; AQUI debería de haber un reflejo.
	 
ESPERAR_SOLTAR_DEC:
    SBIS PINC, PC1
    RJMP ESPERAR_SOLTAR_DEC

    RJMP MAIN_LOOP
*/
/****************************************/


// NON-Interrupt subroutines
MOSTRAR:
    mov Temp, Contador1
    andi Temp, 0x0F
    out PORTB, Temp
    ret
/****************************************/
// Interrupt routines
DELAY_REBOTE:
    LDI d1, 100
Ciclo1:
    LDI d2, 100
Ciclo2:
    DEC d2
    BRNE Ciclo2
    DEC d1
    BRNE Ciclo1
    RET

/****************************************/