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
.def Temp =	r17
.def D1 =	r18
.def D2 =	r19

.org 0x0000

CLC; LIMPIO CARRY
 /****************************************/
// Configuración de la pila
LDI     R17, LOW(RAMEND)
OUT     SPL, R17
LDI     R17, HIGH(RAMEND)
OUT     SPH, R17
/****************************************/
// Configuracion MCU (Entradas y Salidas)

SETUP:
    ; ----- PUERTO B -----; PB0–PB3 como salidas. LEDs para mi contador 1 
	; En este caso Pb0 es menos significativo. 
	LDI r17, 0b0001111
	OUT DDRB, r17

	; Inicialmente apagar LEDs--- Así  estará apagado hasta de inicio
	LDI r17, 0x00
	OUT PORTB, r17; Aqui les doy el apagon


	; ----- PUERTO C -----; PC0 y PC1 como entradas (botones)
	LDI r17, 0b0000000
	OUT DDRC, r17

	; Activar pull-up internos en PC0 y PC1.
	LDI r17, 0b0000011; recordar que es lógica inversa.
	OUT PORTC, r17


	; ----- PUERTO D -----
	; PD1 como salida (LED de carry) En este caso  D2 será donde esté el led, por ahora.
	; En todo caso solo se cambairia a pd0 en caso de ser necesario. 
	LDI r16, 0b0000100
	OUT DDRD, r17

	; Apagar LED de carry al inicio.
	LDI r16, 0x00
	OUT PORTD, r17

	;------------------
	CLR Contador1; limpio contador
	
	
	
/****************************************/
// Loop Infinito
MAIN_LOOP:
; A partir de aqui r16 solo será para mi contador en binario
; Lectura de las entradas, en el registro de r17
	IN  R17, PINC; Leo el estado actual de los pines C
    ANDI R17, 0b0000001    ; leer PC0 
    BRNE BOTON1_PRESIONADO   ; si es 0 ? presionado inc

	IN  R17, PINC; Leo Nuevamente el estado actual de los pines C
	ANDI R17,  0b0000010 ; Aqui leo PC1
	BRNE BOTON2_PRESIONADO   ; si es 0 ? presionado dec
    RJMP MAIN_LOOP

;------Cuando el botón esté presionado-----------
; incrementar
BOTON1_PRESIONADO:
	RCALL DELAY_REBOTE ; evitamos el botonazo

    INC Contador1 ;Incrementar
  //  ANDI Contador1, 0b0001111   ; limitar a 4 bits
    OUT PORTB, Contador1; Se  manda el dato al port B. 
	
ESPERAR_SOLTAR_INC:
    IN Temp, PINC
    ANDI Temp, 0b0000001
    BRNE ESPERAR_SOLTAR_INC

	RJMP MAIN_LOOP

; Decrementar
BOTON2_PRESIONADO:
	RCALL DELAY_REBOTE ; evitamos el botonazo

    CPI Contador1, 0;decrementar
    BREQ NO_DECREMENTAR
    DEC Contador1

NO_DECREMENTAR:
    OUT PORTB, Contador1; AQUI debería de haber un reflejo. 
ESPERAR_SOLTAR_DEC:
    IN Temp, PINC
    ANDI Temp, 0b0000010; Cuando de cero, es porqué está presionado.
    BRNE ESPERAR_SOLTAR_DEC


    RJMP MAIN_LOOP
/****************************************/


// NON-Interrupt subroutines

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